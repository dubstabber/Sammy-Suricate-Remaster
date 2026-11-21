#!/usr/bin/env python3
"""Copy the original in-game HUD bitmaps (panels.wdl / fontes.wdl) into assets.

Most converted PNGs already carry black-key alpha. `fondlife` (PanLife, an
`overlay` panel) and `boink22` (FntNbr_Life digits; A5 fonts treat palette
colour 0 as transparent) were exported opaque, so their colour-0 texels are
keyed out here. Colour 0 is read from the top-left texel because the PCX
conversion does not always map it to exact black (boink22 uses 2,2,2).
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image

SOURCE_DIR = Path("extract-sammy-assets/extracted/godot/textures")
TARGET_DIR = Path("assets/textures/hud")

COPY_AS_IS = [
    "fondscor",  # PANFondScore1 score background
    "boink24",  # fntnbr_score digits
    "lucidd14",  # fntnbr_reach ScoreGoal digits
    "boink20",  # fntnbr_reach2 blinking ScoreGoal digits
    "vbarhear",  # VbarHearts heart window
    "Hbarboos",  # hbarBoost window
    "panboost",  # PANFondBoost
    "panboos2",  # PANFondBoost2/3 ghost trail
]
KEY_COLOUR_ZERO = [
    "fondlife",  # PanLife background (overlay)
    "boink22",  # FntNbr_Life digits (lives, ammo)
]


def key_colour_zero(source: Path, target: Path) -> None:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    key = pixels[0, 0][:3]
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y][:3] == key:
                pixels[x, y] = (0, 0, 0, 0)
    image.save(target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=SOURCE_DIR)
    parser.add_argument("--target-dir", type=Path, default=TARGET_DIR)
    args = parser.parse_args()
    args.target_dir.mkdir(parents=True, exist_ok=True)
    for name in COPY_AS_IS:
        shutil.copyfile(args.source_dir / f"{name}.png", args.target_dir / f"{name.lower()}.png")
    for name in KEY_COLOUR_ZERO:
        key_colour_zero(args.source_dir / f"{name}.png", args.target_dir / f"{name.lower()}.png")
    print(f"wrote {len(COPY_AS_IS) + len(KEY_COLOUR_ZERO)} HUD textures to {args.target_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
