#!/usr/bin/env python3
"""Render the original sammyNN.mid tracks to OGG like the committed sammy01.ogg.

On Windows the game plays its MIDI files through the Microsoft GS Wavetable
synth, i.e. the Roland gm.dls bank (Wine has no default MIDI synth, so the game
is silent there). The committed assets/audio/sammy01.ogg is a TiMidity++ render
with that bank; rendering sammy01 with the default engine below reproduces it
(same length to the sample, 0.99 waveform correlation, 1 LU quieter).

Default engine `timidity`:
- converts a gm.dls you provide (Windows system file, not committed) to SF2
  with tools/dls_to_sf2.py into a temporary directory,
- writes a TiMidity config that maps every bank/drum kit explicitly to that
  SoundFont (TiMidity always loads the system config too, and only explicit
  mappings override it),
- renders with TiMidity defaults, adds the calibrated gain, encodes libvorbis
  160 kbps 44.1 kHz stereo.

Fallback engine `fluidsynth` (no gm.dls available): FluidR3 GM/GS through
libfluidsynth via ctypes; audibly further from the original.

  python3 tools/render_midi_music.py --dls /path/to/gm.dls
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import subprocess
import sys
import tempfile
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import dls_to_sf2  # noqa: E402

MIDI_DIR = Path("extract-sammy-assets/extracted/wrs/sounds")
OUTPUT_DIR = Path("assets/audio")
DEFAULT_TRACKS = ["sammy02", "sammy03", "sammy04", "sammy05", "sammy06", "sammy07"]
SAMPLE_RATE = 44100
VORBIS_BITRATE = "160k"
LIMITER_CEILING = 0.95
# sammy01 rendered with each engine vs the committed sammy01.ogg (-23.6 LUFS).
TIMIDITY_GAIN_DB = 1.0
FLUIDSYNTH_GAIN_DB = 6.5
FLUIDSYNTH_SOUNDFONTS = [Path("/usr/share/soundfonts/FluidR3_GM.sf2"), Path("/usr/share/soundfonts/FluidR3_GS.sf2")]
FLUIDSYNTH_TAIL_SECONDS = 2.0
FLUID_PLAYER_PLAYING = 1
FLUID_OK = 0


def write_timidity_config(soundfont: Path, instruments: list, config_path: Path) -> None:
    lines: list[str] = []
    melodic_banks = sorted({instrument.bank for instrument in instruments if not instrument.drums})
    for bank in melodic_banks:
        lines.append(f"bank {bank}")
        for instrument in instruments:
            if not instrument.drums and instrument.bank == bank:
                lines.append(f"{instrument.program} %font {soundfont} {bank} {instrument.program}")
    for instrument in instruments:
        if instrument.drums:
            lines.append(f"drumset {instrument.program}")
            lines.extend(f"{key} %font {soundfont} 128 {instrument.program} {key}" for key in range(128))
    config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def render_timidity(midi: Path, config: Path, output_wav: Path) -> None:
    subprocess.run(["timidity", "-c", str(config), "-Ow", "-o", str(output_wav), str(midi)], check=True, capture_output=True)


class FluidSynth:
    def __init__(self, library_path: str | None, preload: list[Path]) -> None:
        for dependency in preload:
            ctypes.CDLL(str(dependency), mode=ctypes.RTLD_GLOBAL)
        path = library_path or ctypes.util.find_library("fluidsynth")
        if not path:
            raise SystemExit("libfluidsynth not found; pass --fluidsynth-lib")
        self.lib = ctypes.CDLL(path)
        void_p = ctypes.c_void_p
        signatures = {
            "new_fluid_settings": (void_p, []),
            "fluid_settings_setstr": (ctypes.c_int, [void_p, ctypes.c_char_p, ctypes.c_char_p]),
            "fluid_settings_setnum": (ctypes.c_int, [void_p, ctypes.c_char_p, ctypes.c_double]),
            "fluid_settings_setint": (ctypes.c_int, [void_p, ctypes.c_char_p, ctypes.c_int]),
            "new_fluid_synth": (void_p, [void_p]),
            "fluid_synth_sfload": (ctypes.c_int, [void_p, ctypes.c_char_p, ctypes.c_int]),
            "new_fluid_player": (void_p, [void_p]),
            "fluid_player_add": (ctypes.c_int, [void_p, ctypes.c_char_p]),
            "fluid_player_play": (ctypes.c_int, [void_p]),
            "fluid_player_get_status": (ctypes.c_int, [void_p]),
            "new_fluid_file_renderer": (void_p, [void_p]),
            "fluid_file_renderer_process_block": (ctypes.c_int, [void_p]),
            "delete_fluid_file_renderer": (None, [void_p]),
            "delete_fluid_player": (ctypes.c_int, [void_p]),
            "delete_fluid_synth": (ctypes.c_int, [void_p]),
            "delete_fluid_settings": (None, [void_p]),
        }
        for name, (restype, argtypes) in signatures.items():
            function = getattr(self.lib, name)
            function.restype = restype
            function.argtypes = argtypes

    def render(self, midi: Path, soundfonts: list[Path], output_wav: Path) -> None:
        lib = self.lib
        settings = lib.new_fluid_settings()
        lib.fluid_settings_setstr(settings, b"audio.file.name", str(output_wav).encode())
        lib.fluid_settings_setstr(settings, b"audio.file.type", b"wav")
        lib.fluid_settings_setstr(settings, b"audio.file.format", b"float")
        lib.fluid_settings_setstr(settings, b"player.timing-source", b"sample")
        lib.fluid_settings_setstr(settings, b"synth.midi-bank-select", b"gs")
        lib.fluid_settings_setint(settings, b"synth.lock-memory", 0)
        lib.fluid_settings_setnum(settings, b"synth.sample-rate", float(SAMPLE_RATE))
        synth = lib.new_fluid_synth(settings)
        for soundfont in soundfonts:
            if lib.fluid_synth_sfload(synth, str(soundfont).encode(), 1) < 0:
                raise RuntimeError(f"unable to load soundfont {soundfont}")
        player = lib.new_fluid_player(synth)
        if lib.fluid_player_add(player, str(midi).encode()) != FLUID_OK:
            raise RuntimeError(f"unable to load MIDI {midi}")
        lib.fluid_player_play(player)
        renderer = lib.new_fluid_file_renderer(synth)
        while lib.fluid_player_get_status(player) == FLUID_PLAYER_PLAYING:
            if lib.fluid_file_renderer_process_block(renderer) != FLUID_OK:
                break
        for _block in range(int(FLUIDSYNTH_TAIL_SECONDS * SAMPLE_RATE / 64)):
            if lib.fluid_file_renderer_process_block(renderer) != FLUID_OK:
                break
        lib.delete_fluid_file_renderer(renderer)
        lib.delete_fluid_player(player)
        lib.delete_fluid_synth(synth)
        lib.delete_fluid_settings(settings)


def encode_ogg(source_wav: Path, output_ogg: Path, gain_db: float) -> None:
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-y", "-i", str(source_wav),
            "-af", f"volume={gain_db}dB,alimiter=limit={LIMITER_CEILING}:level=false",
            "-ar", str(SAMPLE_RATE), "-ac", "2",
            "-c:a", "libvorbis", "-b:a", VORBIS_BITRATE,
            str(output_ogg),
        ],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", choices=["timidity", "fluidsynth"], default="timidity")
    parser.add_argument("--dls", type=Path, help="Windows gm.dls (required for the timidity engine)")
    parser.add_argument("--fluidsynth-lib", default=None)
    parser.add_argument("--preload", nargs="*", type=Path, default=[])
    parser.add_argument("--midi-dir", type=Path, default=MIDI_DIR)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--tracks", nargs="+", default=DEFAULT_TRACKS)
    parser.add_argument("--gain-db", type=float, default=None)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sammy-midi-") as temp_name:
        temp_dir = Path(temp_name)
        if args.engine == "timidity":
            if args.dls is None:
                parser.error("--dls is required for the timidity engine")
            instruments, waves = dls_to_sf2.parse_dls(args.dls)
            soundfont = temp_dir / "gm.sf2"
            soundfont.write_bytes(dls_to_sf2.build_sf2(instruments, waves, args.dls.stem))
            config = temp_dir / "gm.cfg"
            write_timidity_config(soundfont, instruments, config)
            gain_db = TIMIDITY_GAIN_DB if args.gain_db is None else args.gain_db

            def render(midi: Path, wav: Path) -> None:
                render_timidity(midi, config, wav)
        else:
            synth = FluidSynth(args.fluidsynth_lib, [path.expanduser() for path in args.preload])
            gain_db = FLUIDSYNTH_GAIN_DB if args.gain_db is None else args.gain_db

            def render(midi: Path, wav: Path) -> None:
                synth.render(midi, FLUIDSYNTH_SOUNDFONTS, wav)

        for track in args.tracks:
            wav_path = temp_dir / f"{track}.wav"
            render(args.midi_dir / f"{track}.mid", wav_path)
            output_path = args.output_dir / f"{track}.ogg"
            encode_ogg(wav_path, output_path, gain_db)
            print(f"rendered {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
