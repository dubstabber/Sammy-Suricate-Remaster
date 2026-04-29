#!/usr/bin/env python3
"""Repair wasp MDL skin color-key alpha and split leg surfaces."""

from __future__ import annotations

import argparse
import copy
import json
import struct
from pathlib import Path

from PIL import Image, ImageDraw

BLACK_KEY = (0, 0, 0)
WASP_MODEL_STEMS = ("wasp1", "wasp1_animated")
WASP_LEG_SURFACE_TRIANGLES = frozenset(range(79, 96))

# These UV polygons come from the wasp1.MDL mirrored/lower-leg triangles.
# Exact-black texels in the source skin are the color key; light grayscale
# texels in these strips are leg strokes and must render black, not white.
MIRRORED_LEG_UV_TRIANGLES = (
    ((25, 30), (34, 12), (36, 22)),
    ((25, 32), (36, 24), (37, 32)),
    ((34, 20), (47, 7), (34, 12)),
    ((47, 7), (36, 22), (34, 12)),
    ((25, 32), (36, 32), (34, 22)),
    ((25, 30), (34, 20), (34, 12)),
    ((36, 24), (55, 21), (37, 32)),
    ((25, 32), (37, 32), (40, 43)),
    ((25, 32), (40, 43), (36, 32)),
)

LOWER_LEG_UV_TRIANGLES = (
    ((43, 46), (55, 63), (56, 46)),
    ((42, 63), (55, 63), (43, 46)),
    ((56, 46), (55, 63), (43, 46)),
    ((43, 46), (55, 63), (42, 63)),
)


def build_uv_mask(size: tuple[int, int], triangles: tuple[tuple[tuple[int, int], tuple[int, int], tuple[int, int]], ...]) -> Image.Image:
    mask = Image.new("1", size, 0)
    draw = ImageDraw.Draw(mask)
    for triangle in triangles:
        draw.polygon(triangle, fill=1)
    return mask


def is_leg_paint(red: int, green: int, blue: int) -> bool:
    channel_max = max(red, green, blue)
    channel_min = min(red, green, blue)
    return channel_max <= 90 or channel_max - channel_min <= 45


def is_lower_right_leg_atlas_pixel(x: int, y: int) -> bool:
    return (x >= 40 and y >= 45) or (x >= 34 and y >= 51)


def repair_body_skin(source_path: Path, target_path: Path) -> None:
    source = Image.open(source_path).convert("RGBA")
    lower_leg_mask = build_uv_mask(source.size, LOWER_LEG_UV_TRIANGLES)
    mask_pixels = lower_leg_mask.load()

    repaired_pixels: list[tuple[int, int, int, int]] = []
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, _alpha = source.getpixel((x, y))
            if (red, green, blue) == BLACK_KEY:
                repaired_pixels.append((0, 0, 0, 0))
            elif (mask_pixels[x, y] or is_lower_right_leg_atlas_pixel(x, y)) and is_leg_paint(red, green, blue):
                repaired_pixels.append((0, 0, 0, 255))
            else:
                repaired_pixels.append((red, green, blue, 255))

    repaired = Image.new("RGBA", source.size)
    repaired.putdata(repaired_pixels)
    target_path.parent.mkdir(parents=True, exist_ok=True)
    repaired.save(target_path)


def repair_leg_skin(source_path: Path, target_path: Path) -> None:
    source = Image.open(source_path).convert("RGBA")
    mirrored_leg_mask = build_uv_mask(source.size, MIRRORED_LEG_UV_TRIANGLES)
    lower_leg_mask = build_uv_mask(source.size, LOWER_LEG_UV_TRIANGLES)
    mirrored_pixels = mirrored_leg_mask.load()
    lower_pixels = lower_leg_mask.load()

    repaired_pixels: list[tuple[int, int, int, int]] = []
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, _alpha = source.getpixel((x, y))
            if (red, green, blue) == BLACK_KEY:
                repaired_pixels.append((0, 0, 0, 0))
            elif mirrored_pixels[x, y]:
                repaired_pixels.append((0, 0, 0, 255))
            elif (lower_pixels[x, y] or is_lower_right_leg_atlas_pixel(x, y)) and is_leg_paint(red, green, blue):
                repaired_pixels.append((0, 0, 0, 255))
            else:
                repaired_pixels.append((0, 0, 0, 0))

    repaired = Image.new("RGBA", source.size)
    repaired.putdata(repaired_pixels)
    target_path.parent.mkdir(parents=True, exist_ok=True)
    repaired.save(target_path)


def repair_wasp_skins(source_dir: Path, target_dir: Path) -> None:
    for source_path in sorted(source_dir.glob("wasp1_skin*.png")):
        repair_body_skin(source_path, target_dir / source_path.name)
        repair_leg_skin(source_path, target_dir / "legs" / f"{source_path.stem}_legs.png")


def pad4(payload: bytearray) -> None:
    while len(payload) % 4:
        payload.append(0)


def append_index_accessor(gltf: dict, blob: bytearray, indices: list[int]) -> int:
    pad4(blob)
    payload = struct.pack(f"<{len(indices)}I", *indices)
    view_index = len(gltf["bufferViews"])
    gltf["bufferViews"].append(
        {
            "buffer": 0,
            "byteOffset": len(blob),
            "byteLength": len(payload),
            "target": 34963,
        }
    )
    blob.extend(payload)

    accessor_index = len(gltf["accessors"])
    gltf["accessors"].append(
        {
            "bufferView": view_index,
            "componentType": 5125,
            "count": len(indices),
            "type": "SCALAR",
            "min": [min(indices)],
            "max": [max(indices)],
        }
    )
    return accessor_index


def read_indices(gltf: dict, blob: bytes, accessor_index: int) -> list[int]:
    accessor = gltf["accessors"][accessor_index]
    buffer_view = gltf["bufferViews"][accessor["bufferView"]]
    byte_offset = int(buffer_view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    count = int(accessor["count"])
    component_type = int(accessor["componentType"])
    if component_type == 5125:
        fmt = f"<{count}I"
    elif component_type == 5123:
        fmt = f"<{count}H"
    else:
        raise ValueError(f"unsupported index component type {component_type}")
    return list(struct.unpack_from(fmt, blob, byte_offset))


def split_wasp_model_surfaces(source_gltf_path: Path, target_gltf_path: Path) -> None:
    gltf = json.loads(source_gltf_path.read_text())
    source_bin_path = source_gltf_path.with_name(gltf["buffers"][0]["uri"])
    blob = bytearray(source_bin_path.read_bytes())

    mesh = gltf["meshes"][0]
    original_primitive = mesh["primitives"][0]
    indices = read_indices(gltf, blob, int(original_primitive["indices"]))
    if len(indices) % 3:
        raise ValueError(f"{source_gltf_path} index buffer is not triangle-aligned")

    body_indices: list[int] = []
    leg_indices: list[int] = []
    for triangle_index in range(len(indices) // 3):
        triangle_indices = indices[triangle_index * 3 : triangle_index * 3 + 3]
        if triangle_index in WASP_LEG_SURFACE_TRIANGLES:
            leg_indices.extend(triangle_indices)
        else:
            body_indices.extend(triangle_indices)

    body_accessor = append_index_accessor(gltf, blob, body_indices)
    leg_accessor = append_index_accessor(gltf, blob, leg_indices)
    gltf["buffers"][0]["uri"] = target_gltf_path.with_suffix(".bin").name
    gltf["buffers"][0]["byteLength"] = len(blob)

    body_material = gltf["materials"][0]
    body_material["doubleSided"] = True
    body_material["alphaMode"] = "BLEND"

    leg_image_index = len(gltf["images"])
    gltf["images"].append({"uri": "skins/legs/wasp1_skin0_legs.png"})
    leg_texture_index = len(gltf["textures"])
    gltf["textures"].append({"source": leg_image_index})
    leg_material = copy.deepcopy(body_material)
    leg_material["name"] = "wasp1_leg_material"
    leg_material.setdefault("pbrMetallicRoughness", {})
    leg_material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": leg_texture_index}
    leg_material["doubleSided"] = True
    leg_material["alphaMode"] = "BLEND"
    leg_material_index = len(gltf["materials"])
    gltf["materials"].append(leg_material)

    body_primitive = copy.deepcopy(original_primitive)
    body_primitive["indices"] = body_accessor
    body_primitive["material"] = 0
    leg_primitive = copy.deepcopy(original_primitive)
    leg_primitive["indices"] = leg_accessor
    leg_primitive["material"] = leg_material_index
    mesh["primitives"] = [body_primitive, leg_primitive]

    target_gltf_path.parent.mkdir(parents=True, exist_ok=True)
    target_gltf_path.write_text(json.dumps(gltf, indent=2) + "\n")
    target_gltf_path.with_suffix(".bin").write_bytes(blob)


def split_wasp_models(source_model_dir: Path, target_model_dir: Path) -> None:
    for stem in WASP_MODEL_STEMS:
        split_wasp_model_surfaces(source_model_dir / f"{stem}.gltf", target_model_dir / f"{stem}.gltf")


def ensure_lossless_import_sidecars(target_dir: Path) -> None:
    for import_path in sorted(target_dir.glob("**/*.png.import")):
        text = import_path.read_text()
        replacements = {
            '"vram_texture": true': '"vram_texture": false',
            "compress/mode=1": "compress/mode=0",
            "compress/mode=2": "compress/mode=0",
            "mipmaps/generate=true": "mipmaps/generate=false",
            "process/fix_alpha_border=true": "process/fix_alpha_border=false",
            "detect_3d/compress_to=1": "detect_3d/compress_to=0",
        }
        for old, new in replacements.items():
            text = text.replace(old, new)
        import_path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("extract-sammy-assets/extracted/godot/models/wasp1/skins"),
    )
    parser.add_argument(
        "--target-dir",
        type=Path,
        default=Path("assets/models/wasp1/skins"),
    )
    parser.add_argument(
        "--source-model-dir",
        type=Path,
        default=Path("extract-sammy-assets/extracted/godot/models/wasp1"),
    )
    parser.add_argument(
        "--target-model-dir",
        type=Path,
        default=Path("assets/models/wasp1"),
    )
    args = parser.parse_args()
    repair_wasp_skins(args.source_dir, args.target_dir)
    split_wasp_models(args.source_model_dir, args.target_model_dir)
    ensure_lossless_import_sidecars(args.target_dir)


if __name__ == "__main__":
    main()
