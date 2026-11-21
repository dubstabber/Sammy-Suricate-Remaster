#!/usr/bin/env python3
"""Convert a DLS Level 1 bank (e.g. Windows' gm.dls) to an SF2 SoundFont.

The original game plays its MIDI music through the Windows "Microsoft GS
Wavetable" synth, whose instruments are the Roland gm.dls bank. Converting
that bank to SF2 lets TiMidity/FluidSynth render the tracks with the original
instruments (see tools/render_midi_music.py).

The bank is a Windows system file: the converted SoundFont is a local build
input and must not be committed.

DLS -> SF2 mapping (DLS1 connection blocks, scales are 16.16 fixed point):
- EG1 attack/decay/release (timecents) -> volume envelope generators; EG1
  sustain (0.1% of the 96 dB envelope range) -> sustainVolEnv centibels;
  key number -> EG1 decay -> keynumToVolEnvDecay.
- EG2 -> modulation envelope, EG2 -> pitch -> modEnvToPitch.
- LFO frequency/delay -> both SF2 LFOs; LFO -> pitch -> vibLfoToPitch;
  LFO -> attenuation -> modLfoToVolume; LFO -> pitch via CC1 -> a CC1
  modulator on vibLfoToPitch.
- Pan, wsmp attenuation/unity note/fine tune/loops, key groups, velocity ->
  EG attack (as SF2 modulators).
"""

from __future__ import annotations

import argparse
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path

# DLS1 connection sources / destinations.
SRC_NONE = 0x0000
SRC_LFO = 0x0001
SRC_KEYONVELOCITY = 0x0002
SRC_KEYNUMBER = 0x0003
SRC_EG2 = 0x0005
SRC_CC1 = 0x0081
DST_ATTENUATION = 0x0001
DST_PITCH = 0x0003
DST_PAN = 0x0004
DST_LFO_FREQUENCY = 0x0104
DST_LFO_STARTDELAY = 0x0105
DST_EG1_ATTACKTIME = 0x0206
DST_EG1_DECAYTIME = 0x0207
DST_EG1_RELEASETIME = 0x0209
DST_EG1_SUSTAINLEVEL = 0x020A
DST_EG2_ATTACKTIME = 0x030A
DST_EG2_DECAYTIME = 0x030B
DST_EG2_RELEASETIME = 0x030D
DST_EG2_SUSTAINLEVEL = 0x030E
F_INSTRUMENT_DRUMS = 0x80000000
DLS_ZERO_TIME = -32768.0

# SF2 generator operators.
GEN_MOD_LFO_TO_PITCH = 5
GEN_VIB_LFO_TO_PITCH = 6
GEN_MOD_ENV_TO_PITCH = 7
GEN_MOD_LFO_TO_VOLUME = 13
GEN_PAN = 17
GEN_DELAY_MOD_LFO = 21
GEN_FREQ_MOD_LFO = 22
GEN_DELAY_VIB_LFO = 23
GEN_FREQ_VIB_LFO = 24
GEN_ATTACK_MOD_ENV = 26
GEN_DECAY_MOD_ENV = 28
GEN_SUSTAIN_MOD_ENV = 29
GEN_RELEASE_MOD_ENV = 30
GEN_ATTACK_VOL_ENV = 34
GEN_DECAY_VOL_ENV = 36
GEN_SUSTAIN_VOL_ENV = 37
GEN_RELEASE_VOL_ENV = 38
GEN_KEYNUM_TO_VOL_ENV_DECAY = 40
GEN_INSTRUMENT = 41
GEN_KEY_RANGE = 43
GEN_VEL_RANGE = 44
GEN_INITIAL_ATTENUATION = 48
GEN_FINE_TUNE = 52
GEN_SAMPLE_ID = 53
GEN_SAMPLE_MODES = 54
GEN_EXCLUSIVE_CLASS = 57
GEN_OVERRIDING_ROOT_KEY = 58
SF2_MIN_TIMECENTS = -12000
SF2_MAX_TIMECENTS = 8000
SAMPLE_PADDING = 46
# SF2 modulator source operands: note-on velocity / CC1, linear, unipolar, positive.
MOD_SRC_VELOCITY = 0x0002
MOD_SRC_CC1 = 0x0081


@dataclass
class Wave:
    rate: int
    samples: bytes  # 16-bit signed little-endian mono
    unity_note: int = 60
    fine_tune: int = 0
    attenuation_cb: float = 0.0
    loop: tuple[int, int] | None = None


@dataclass
class Region:
    key_range: tuple[int, int]
    vel_range: tuple[int, int]
    key_group: int
    wave_index: int
    unity_note: int | None = None
    fine_tune: int = 0
    attenuation_cb: float = 0.0
    loop: tuple[int, int] | None = None
    has_wsmp: bool = False
    connections: list[tuple[int, int, int, int, float]] = field(default_factory=list)


@dataclass
class Instrument:
    name: str
    bank: int
    program: int
    drums: bool
    regions: list[Region]
    connections: list[tuple[int, int, int, int, float]]


class Riff:
    def __init__(self, data: bytes) -> None:
        self.data = data

    def walk(self, start: int, end: int):
        pos = start
        while pos + 8 <= end:
            chunk_id = self.data[pos : pos + 4]
            size = struct.unpack_from("<I", self.data, pos + 4)[0]
            if chunk_id in (b"LIST", b"RIFF"):
                yield chunk_id, self.data[pos + 8 : pos + 12], pos + 12, pos + 8 + size
            else:
                yield chunk_id, None, pos + 8, pos + 8 + size
            pos += 8 + size + (size & 1)


def read_c_string(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("latin-1").strip()


def parse_connections(riff: Riff, start: int, end: int) -> list[tuple[int, int, int, int, float]]:
    connections = []
    for chunk_id, _type, data_start, _data_end in riff.walk(start, end):
        if chunk_id not in (b"art1", b"art2"):
            continue
        header_size, count = struct.unpack_from("<II", riff.data, data_start)
        for index in range(count):
            source, control, destination, transform, scale = struct.unpack_from("<HHHHi", riff.data, data_start + header_size + index * 12)
            connections.append((source, control, destination, transform, scale / 65536.0))
    return connections


def parse_wsmp(data: bytes, offset: int) -> tuple[int, int, float, tuple[int, int] | None]:
    header_size, unity, fine, attenuation, _options, loop_count = struct.unpack_from("<IHhiII", data, offset)
    loop = None
    if loop_count:
        _loop_size, _loop_type, loop_start, loop_length = struct.unpack_from("<IIII", data, offset + header_size)
        loop = (loop_start, loop_length)
    return unity, fine, -attenuation / 65536.0, loop


def parse_dls(path: Path) -> tuple[list[Instrument], list[Wave]]:
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"DLS ":
        raise ValueError(f"{path} is not a DLS file")
    riff = Riff(data)
    top = list(riff.walk(12, len(data)))
    cue_offsets: list[int] = []
    waves_by_offset: dict[int, Wave] = {}
    wvpl_start = 0
    for chunk_id, list_type, start, end in top:
        if chunk_id == b"ptbl":
            header_size, count = struct.unpack_from("<II", data, start)
            cue_offsets = list(struct.unpack_from(f"<{count}I", data, start + header_size))
        elif list_type == b"wvpl":
            wvpl_start = start
            for wave_id, wave_type, wave_start, wave_end in riff.walk(start, end):
                if wave_type != b"wave":
                    continue
                wave = Wave(rate=22050, samples=b"")
                bits = 16
                for sub_id, _sub_type, sub_start, sub_end in riff.walk(wave_start, wave_end):
                    if sub_id == b"fmt ":
                        _tag, channels, rate, _avg, _align, bits = struct.unpack_from("<HHIIHH", data, sub_start)
                        if channels != 1:
                            raise ValueError("only mono DLS waves are supported")
                        wave.rate = rate
                    elif sub_id == b"wsmp":
                        wave.unity_note, wave.fine_tune, wave.attenuation_cb, wave.loop = parse_wsmp(data, sub_start)
                    elif sub_id == b"data":
                        raw = data[sub_start:sub_end]
                        if bits == 8:
                            raw = b"".join(struct.pack("<h", (value - 128) << 8) for value in raw)
                        wave.samples = raw
                # ptbl cues are offsets from the start of the wvpl list data.
                waves_by_offset[wave_start - 12 - wvpl_start] = wave
    waves = [waves_by_offset[offset] for offset in cue_offsets]

    instruments: list[Instrument] = []
    lins = next(item for item in top if item[1] == b"lins")
    for _chunk, ins_type, ins_start, ins_end in riff.walk(lins[2], lins[3]):
        if ins_type != b"ins ":
            continue
        name = ""
        bank_word = program = 0
        regions: list[Region] = []
        connections: list[tuple[int, int, int, int, float]] = []
        for chunk_id, list_type, start, end in riff.walk(ins_start, ins_end):
            if chunk_id == b"insh":
                _count, bank_word, program = struct.unpack_from("<III", data, start)
            elif list_type == b"lart":
                connections = parse_connections(riff, start, end)
            elif list_type == b"INFO":
                for info_id, _info_type, info_start, info_end in riff.walk(start, end):
                    if info_id == b"INAM":
                        name = read_c_string(data[info_start:info_end])
            elif list_type == b"lrgn":
                for _rgn, rgn_type, rgn_start, rgn_end in riff.walk(start, end):
                    if rgn_type != b"rgn ":
                        continue
                    region = Region((0, 127), (0, 127), 0, 0)
                    for sub_id, sub_type, sub_start, sub_end in riff.walk(rgn_start, rgn_end):
                        if sub_id == b"rgnh":
                            key_lo, key_hi, vel_lo, vel_hi, _options, key_group = struct.unpack_from("<HHHHHH", data, sub_start)
                            region.key_range = (key_lo, key_hi)
                            region.vel_range = (vel_lo, vel_hi)
                            region.key_group = key_group
                        elif sub_id == b"wsmp":
                            region.unity_note, region.fine_tune, region.attenuation_cb, region.loop = parse_wsmp(data, sub_start)
                            region.has_wsmp = True
                        elif sub_id == b"wlnk":
                            region.wave_index = struct.unpack_from("<HHII", data, sub_start)[3]
                        elif sub_type == b"lart":
                            region.connections = parse_connections(riff, sub_start, sub_end)
                    regions.append(region)
        drums = bool(bank_word & F_INSTRUMENT_DRUMS)
        bank = 128 if drums else (bank_word >> 8) & 0x7F
        instruments.append(Instrument(name or f"inst{program}", bank, program & 0x7F, drums, regions, connections))
    return instruments, waves


def clamp(value: float, low: int, high: int) -> int:
    return int(max(low, min(high, round(value))))


def timecents(value: float) -> int:
    if value <= DLS_ZERO_TIME:
        return SF2_MIN_TIMECENTS
    return clamp(value, SF2_MIN_TIMECENTS, SF2_MAX_TIMECENTS)


def articulation_generators(connections: list[tuple[int, int, int, int, float]]) -> tuple[dict[int, int], list[tuple[int, int, int]]]:
    """Return SF2 generators and (source, destination, amount) modulators."""
    generators: dict[int, int] = {}
    modulators: list[tuple[int, int, int]] = []
    decay_base: float | None = None
    decay_key_scale = 0.0
    for source, control, destination, _transform, scale in connections:
        if source == SRC_NONE and control == 0:
            if destination == DST_EG1_ATTACKTIME:
                generators[GEN_ATTACK_VOL_ENV] = timecents(scale)
            elif destination == DST_EG1_DECAYTIME:
                decay_base = scale
            elif destination == DST_EG1_RELEASETIME:
                generators[GEN_RELEASE_VOL_ENV] = timecents(scale)
            elif destination == DST_EG1_SUSTAINLEVEL:
                # Percent of the 96 dB envelope range -> centibels of attenuation.
                generators[GEN_SUSTAIN_VOL_ENV] = clamp((1000.0 - scale) * 0.96, 0, 1440)
            elif destination == DST_EG2_ATTACKTIME:
                generators[GEN_ATTACK_MOD_ENV] = timecents(scale)
            elif destination == DST_EG2_DECAYTIME:
                generators[GEN_DECAY_MOD_ENV] = timecents(scale)
            elif destination == DST_EG2_RELEASETIME:
                generators[GEN_RELEASE_MOD_ENV] = timecents(scale)
            elif destination == DST_EG2_SUSTAINLEVEL:
                generators[GEN_SUSTAIN_MOD_ENV] = clamp(1000.0 - scale, 0, 1000)
            elif destination == DST_LFO_FREQUENCY:
                generators[GEN_FREQ_MOD_LFO] = clamp(scale, -16000, 4500)
                generators[GEN_FREQ_VIB_LFO] = clamp(scale, -16000, 4500)
            elif destination == DST_LFO_STARTDELAY:
                generators[GEN_DELAY_MOD_LFO] = timecents(scale)
                generators[GEN_DELAY_VIB_LFO] = timecents(scale)
            elif destination == DST_PAN:
                generators[GEN_PAN] = clamp(scale, -500, 500)
        elif source == SRC_LFO and destination == DST_PITCH and control == 0:
            generators[GEN_VIB_LFO_TO_PITCH] = clamp(scale, -12000, 12000)
        elif source == SRC_LFO and destination == DST_PITCH and control == SRC_CC1:
            modulators.append((MOD_SRC_CC1, GEN_VIB_LFO_TO_PITCH, clamp(scale, -12000, 12000)))
        elif source == SRC_LFO and destination == DST_ATTENUATION and control == 0:
            generators[GEN_MOD_LFO_TO_VOLUME] = clamp(abs(scale), -960, 960)
        elif source == SRC_EG2 and destination == DST_PITCH:
            generators[GEN_MOD_ENV_TO_PITCH] = clamp(scale, -12000, 12000)
        elif source == SRC_KEYNUMBER and destination == DST_EG1_DECAYTIME:
            decay_key_scale = scale
        elif source == SRC_KEYONVELOCITY and destination == DST_EG1_ATTACKTIME:
            modulators.append((MOD_SRC_VELOCITY, GEN_ATTACK_VOL_ENV, clamp(scale, -12000, 12000)))
        elif source == SRC_KEYONVELOCITY and destination == DST_EG2_ATTACKTIME:
            modulators.append((MOD_SRC_VELOCITY, GEN_ATTACK_MOD_ENV, clamp(scale, -12000, 12000)))
    if decay_base is not None:
        # DLS: decay = base + scale * key/128. SF2: decay = gen + keynumTo * (60 - key).
        per_key = -decay_key_scale / 128.0
        generators[GEN_DECAY_VOL_ENV] = timecents(decay_base + decay_key_scale * 60.0 / 128.0) if decay_base > DLS_ZERO_TIME else SF2_MIN_TIMECENTS
        if per_key:
            generators[GEN_KEYNUM_TO_VOL_ENV_DECAY] = clamp(per_key, -1200, 1200)
    return generators, modulators


def pack_gen(operator: int, value: int | tuple[int, int]) -> bytes:
    if isinstance(value, tuple):
        return struct.pack("<HBB", operator, value[0], value[1])
    return struct.pack("<Hh", operator, value)


def chunk(chunk_id: bytes, payload: bytes) -> bytes:
    # SF2 requires even-sized chunks (zero-padded strings); TiMidity does not
    # skip RIFF pad bytes, so the padding is part of the declared size.
    if len(payload) & 1:
        payload += b"\0"
    return chunk_id + struct.pack("<I", len(payload)) + payload


def list_chunk(list_type: bytes, payload: bytes) -> bytes:
    return chunk(b"LIST", list_type + payload)


def name20(name: str) -> bytes:
    return name.encode("latin-1", errors="replace")[:19].ljust(20, b"\0")


def build_sf2(instruments: list[Instrument], waves: list[Wave], bank_name: str) -> bytes:
    sample_data = bytearray()
    shdr = bytearray()
    sample_cache: dict[tuple, int] = {}
    wave_offsets: dict[int, int] = {}

    def wave_offset(index: int) -> int:
        if index not in wave_offsets:
            wave_offsets[index] = len(sample_data) // 2
            sample_data.extend(waves[index].samples)
            sample_data.extend(b"\0\0" * SAMPLE_PADDING)
        return wave_offsets[index]

    def sample_id(region: Region) -> int:
        wave = waves[region.wave_index]
        unity = region.unity_note if region.has_wsmp else wave.unity_note
        fine = region.fine_tune if region.has_wsmp else wave.fine_tune
        loop = region.loop if region.has_wsmp else wave.loop
        key = (region.wave_index, unity, fine, loop)
        if key in sample_cache:
            return sample_cache[key]
        start = wave_offset(region.wave_index)
        length = len(wave.samples) // 2
        if loop:
            loop_start, loop_end = start + loop[0], start + loop[0] + loop[1]
        else:
            loop_start, loop_end = start, start + max(length - 1, 0)
        shdr.extend(name20(f"w{region.wave_index}_{len(sample_cache)}"))
        shdr.extend(struct.pack("<IIIIIBbHH", start, start + length, loop_start, loop_end, wave.rate, clamp(unity, 0, 127), clamp(fine, -99, 99), 0, 1))
        sample_cache[key] = len(sample_cache)
        return sample_cache[key]

    inst_records = bytearray()
    ibag = bytearray()
    igen = bytearray()
    imod = bytearray()
    igen_count = imod_count = ibag_count = 0
    phdr = bytearray()
    pbag = bytearray()
    pgen = bytearray()
    preset_order = sorted(range(len(instruments)), key=lambda index: (instruments[index].bank, instruments[index].program))
    for inst_index, instrument in enumerate(instruments):
        inst_records.extend(name20(instrument.name) + struct.pack("<H", ibag_count))
        base_generators, base_modulators = articulation_generators(instrument.connections)
        for region in instrument.regions:
            ibag.extend(struct.pack("<HH", igen_count, imod_count))
            ibag_count += 1
            generators = dict(base_generators)
            modulators = list(base_modulators)
            if region.connections:
                generators, modulators = articulation_generators(region.connections)
            wave = waves[region.wave_index]
            attenuation = region.attenuation_cb if region.has_wsmp else wave.attenuation_cb
            loop = region.loop if region.has_wsmp else wave.loop
            generators[GEN_INITIAL_ATTENUATION] = clamp(attenuation, 0, 1440)
            generators[GEN_SAMPLE_MODES] = 1 if loop else 0
            if region.key_group:
                generators[GEN_EXCLUSIVE_CLASS] = region.key_group
            entries = [pack_gen(GEN_KEY_RANGE, region.key_range), pack_gen(GEN_VEL_RANGE, region.vel_range)]
            entries += [pack_gen(operator, value) for operator, value in sorted(generators.items())]
            entries.append(pack_gen(GEN_SAMPLE_ID, sample_id(region)))
            igen.extend(b"".join(entries))
            igen_count += len(entries)
            for source, destination, amount in modulators:
                imod.extend(struct.pack("<HHhHH", source, destination, amount, 0, 0))
                imod_count += 1
    inst_records.extend(name20("EOI") + struct.pack("<H", ibag_count))
    ibag.extend(struct.pack("<HH", igen_count, imod_count))
    igen.extend(struct.pack("<HH", 0, 0))
    imod.extend(b"\0" * 10)

    for bag_index, inst_index in enumerate(preset_order):
        instrument = instruments[inst_index]
        phdr.extend(name20(instrument.name) + struct.pack("<HHHIII", instrument.program, instrument.bank, bag_index, 0, 0, 0))
        pbag.extend(struct.pack("<HH", bag_index, 0))
        pgen.extend(pack_gen(GEN_INSTRUMENT, inst_index))
    phdr.extend(name20("EOP") + struct.pack("<HHHIII", 0, 0, len(preset_order), 0, 0, 0))
    pbag.extend(struct.pack("<HH", len(preset_order), 0))
    pgen.extend(struct.pack("<HH", 0, 0))
    pmod = b"\0" * 10
    shdr.extend(name20("EOS") + b"\0" * 26)

    info = chunk(b"ifil", struct.pack("<HH", 2, 1)) + chunk(b"isng", b"EMU8000\0") + chunk(b"INAM", bank_name.encode("latin-1") + b"\0")
    sdta = chunk(b"smpl", bytes(sample_data))
    pdta = b"".join([
        chunk(b"phdr", bytes(phdr)), chunk(b"pbag", bytes(pbag)), chunk(b"pmod", pmod), chunk(b"pgen", bytes(pgen)),
        chunk(b"inst", bytes(inst_records)), chunk(b"ibag", bytes(ibag)), chunk(b"imod", bytes(imod)), chunk(b"igen", bytes(igen)),
        chunk(b"shdr", bytes(shdr)),
    ])
    body = b"sfbk" + list_chunk(b"INFO", info) + list_chunk(b"sdta", sdta) + list_chunk(b"pdta", pdta)
    return b"RIFF" + struct.pack("<I", len(body)) + body


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dls", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    instruments, waves = parse_dls(args.dls)
    args.output.write_bytes(build_sf2(instruments, waves, args.dls.stem))
    regions = sum(len(instrument.regions) for instrument in instruments)
    print(f"converted {len(instruments)} instruments, {regions} regions, {len(waves)} waves -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
