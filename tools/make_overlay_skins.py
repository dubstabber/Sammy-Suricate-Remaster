#!/usr/bin/env python3
"""Write black-keyed copies of MDL skins for Acknex `overlay` entities.

WDL InitMDL sets `my.overlay = 1` for Flag1 entities (e.g. grate1, huttop2 in
the original levels); the A5 engine then renders colour-0 (pure black) texels
transparent. Model skins themselves stay opaque (black is real detail on
characters), so this writes `<skin>_overlay.png` next to each skin with alpha 0
on exact-black texels, for the level builder to use only on overlay entities.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

DEFAULT_MODELS = ["grate1", "huttop2", "panwasp"]


def key_black(source: Path, target: Path) -> float:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    keyed = 0
    for y in range(height):
        for x in range(width):
            red, green, blue, _alpha = pixels[x, y]
            if red == 0 and green == 0 and blue == 0:
                pixels[x, y] = (0, 0, 0, 0)
                keyed += 1
    image.save(target)
    return keyed / max(width * height, 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-root", type=Path, default=Path("assets/models"))
    parser.add_argument("--models", nargs="+", default=DEFAULT_MODELS)
    args = parser.parse_args()
    for model in args.models:
        skins = sorted(path for path in (args.model_root / model / "skins").glob("*.png") if not path.stem.endswith("_overlay"))
        if not skins:
            raise FileNotFoundError(f"no skins for {model}")
        for skin in skins:
            target = skin.with_name(f"{skin.stem}_overlay.png")
            ratio = key_black(skin, target)
            print(f"{target}: {ratio:.1%} keyed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
