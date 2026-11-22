#!/usr/bin/env python3
"""Apply the A5 sprite colour key to converted sprite textures.

The original engine uploads 24-bit sprite bitmaps as RGB565 textures and draws
non-flare sprites with the D3D colour key 0 (sammypolish.exe sub_448BE0 /
sub_42C790): every texel whose RGB565 value is 0 (red < 8, green < 4,
blue < 8) is transparent. The extracted PNGs only keyed exact black, which
leaves dark specks around gems and level sprites, so this re-keys them in
place. It is idempotent; tools/convert_level_wmb.py applies it to the sprites
it copies.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

DEFAULT_DIRS = [
    "assets/textures/sprites",
    "assets/textures/key_diamonds",
    "assets/textures/score",
    "assets/textures/heart",
]


def is_rgb565_black(red: int, green: int, blue: int) -> bool:
    return red < 8 and green < 4 and blue < 8


def key_rgb565_black(path: Path) -> int:
    """Makes RGB565-black texels transparent; returns how many changed."""
    image = Image.open(path)
    mode = image.mode
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    changed = 0
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha != 0 and is_rgb565_black(red, green, blue):
                pixels[x, y] = (0, 0, 0, 0)
                changed += 1
    if changed or mode != "RGBA":
        rgba.save(path)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, help="PNG files or directories (default: the sprite texture dirs)")
    args = parser.parse_args()
    targets = args.paths or [Path(directory) for directory in DEFAULT_DIRS]
    for target in targets:
        files = sorted(target.glob("*.png")) if target.is_dir() else [target]
        for path in files:
            changed = key_rgb565_black(path)
            if changed:
                print(f"{path}: keyed {changed} texels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
