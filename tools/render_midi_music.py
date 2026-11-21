#!/usr/bin/env python3
"""Render the original sammyNN.mid level tracks to OGG with FluidSynth.

The extraction-time OGGs (extract-sammy-assets/extracted/godot/audio) were
produced by ffmpeg's libopenmpt MIDI import, whose built-in instruments sound
nothing like the original. The committed assets/audio/sammy01.ogg is a FluidR3
soundfont render; this tool reproduces that pipeline for the other tracks:

- FluidSynth (offline file renderer, sample timing) with FluidR3_GM.sf2 plus the
  FluidR3_GS.sf2 GS-variation supplement (Roland GS bank select),
- a release/reverb tail after the last MIDI event,
- a fixed gain calibrated so sammy01 rendered here matches the committed
  sammy01.ogg integrated loudness (-23.6 LUFS), then a limiter,
- libvorbis 160 kbps, 44.1 kHz stereo (same as the committed sammy01.ogg).

FluidSynth is loaded through ctypes. Pass `--fluidsynth-lib` (and `--preload`
for missing dependencies) when no system libfluidsynth is installed, e.g. the
Lutris runtime copy:

  python3 tools/render_midi_music.py \\
    --fluidsynth-lib ~/.local/share/lutris/runtime/Ubuntu-18.04-x86_64/libfluidsynth.so.1 \\
    --preload ~/.local/share/lutris/runtime/Ubuntu-18.04-x86_64/libtinfo.so.5 \\
              ~/.local/share/lutris/runtime/Ubuntu-18.04-x86_64/libreadline.so.7
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import subprocess
import tempfile
from pathlib import Path

MIDI_DIR = Path("extract-sammy-assets/extracted/wrs/sounds")
OUTPUT_DIR = Path("assets/audio")
DEFAULT_SOUNDFONTS = [Path("/usr/share/soundfonts/FluidR3_GM.sf2"), Path("/usr/share/soundfonts/FluidR3_GS.sf2")]
DEFAULT_TRACKS = ["sammy02", "sammy03", "sammy04", "sammy05", "sammy06", "sammy07"]
SAMPLE_RATE = 44100
TAIL_SECONDS = 2.0
# sammy01 rendered with these settings is -30.1 LUFS; the committed sammy01.ogg is -23.6 LUFS.
CALIBRATED_GAIN_DB = 6.5
LIMITER_CEILING = 0.95
VORBIS_BITRATE = "160k"
FLUID_PLAYER_PLAYING = 1
FLUID_OK = 0


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

    def render(self, midi: Path, soundfonts: list[Path], output_wav: Path, tail_seconds: float) -> None:
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
        # Let releases and reverb ring out (64-sample blocks).
        for _block in range(int(tail_seconds * SAMPLE_RATE / 64)):
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
    parser.add_argument("--fluidsynth-lib", default=None)
    parser.add_argument("--preload", nargs="*", type=Path, default=[])
    parser.add_argument("--soundfonts", nargs="+", type=Path, default=DEFAULT_SOUNDFONTS)
    parser.add_argument("--midi-dir", type=Path, default=MIDI_DIR)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--tracks", nargs="+", default=DEFAULT_TRACKS)
    parser.add_argument("--gain-db", type=float, default=CALIBRATED_GAIN_DB)
    parser.add_argument("--tail-seconds", type=float, default=TAIL_SECONDS)
    args = parser.parse_args()

    synth = FluidSynth(args.fluidsynth_lib, [path.expanduser() for path in args.preload])
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sammy-midi-") as temp_dir:
        for track in args.tracks:
            wav_path = Path(temp_dir) / f"{track}.wav"
            synth.render(args.midi_dir / f"{track}.mid", args.soundfonts, wav_path, args.tail_seconds)
            output_path = args.output_dir / f"{track}.ogg"
            encode_ogg(wav_path, output_path, args.gain_db)
            print(f"rendered {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
