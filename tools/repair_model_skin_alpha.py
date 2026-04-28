#!/usr/bin/env python3
"""Repair generated RGB565 MDL skin alpha for selected converted models."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def force_opaque_png(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    if all(alpha == 255 for *_, alpha in image.getdata()):
        return
    image.putdata([(red, green, blue, 255) for red, green, blue, _ in image.getdata()])
    image.save(path)


def force_opaque_gltf(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = False
    for material in data.get("materials", []):
        if "alphaMode" in material:
            material.pop("alphaMode", None)
            material.pop("alphaCutoff", None)
            changed = True
    if changed:
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def repair_model_dir(model_dir: Path) -> None:
    skins_dir = model_dir / "skins"
    if skins_dir.exists():
        for skin_path in sorted(skins_dir.glob("*.png")):
            force_opaque_png(skin_path)
    for gltf_path in sorted(model_dir.glob("*.gltf")):
        force_opaque_gltf(gltf_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("model_dirs", nargs="+", type=Path)
    args = parser.parse_args()
    for model_dir in args.model_dirs:
        repair_model_dir(model_dir)


if __name__ == "__main__":
    main()
