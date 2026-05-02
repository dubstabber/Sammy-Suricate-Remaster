#!/usr/bin/env python3
"""Convert selected Sammy Suricate WMB4 props into Godot glTF assets.

This is intentionally narrow: it handles the small static door/gate WMB files
used by the key-diamond gate work and similarly small platform WMB props, not
the full WMB level format.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image


SOURCE_WMB_NAMES = [
    "doorRed.wmb",
    "dooryell.wmb",
    "doororan.wmb",
    "doorBlue.wmb",
    "doormage.wmb",
    "doormag.wmb",
    "doorgree.wmb",
    "doorexit.wmb",
    "doordark.wmb",
    "doorwk1.wmb",
    "doorwk2.wmb",
    "doorwk3.wmb",
    "doorwk4.wmb",
    "dfixRed.wmb",
    "dfixyell.wmb",
    "dfixOran.wmb",
    "dfixblue.wmb",
    "dfixmag.wmb",
    "dfixgree.wmb",
    "dfixall.wmb",
    "doneRed.wmb",
    "doneyell.wmb",
    "doneOran.wmb",
    "doneBlue.wmb",
    "doneMage.wmb",
    "donegree.wmb",
]

WMB_MAGIC = b"WMB4"
ACKNEX_TO_GODOT_SCALE = 0.01
UNUSED_POLY_LINK = 0xFFFF
TEXINFO_NO_RENDER_FLAG = 0x8


@dataclass(frozen=True)
class TextureInfo:
    name: str
    filename: str
    width: int
    height: int
    image_path: Path


@dataclass(frozen=True)
class PolygonInfo:
    vertices: list[int]
    field_side: int
    field_mapping: int
    plane_index: int


@dataclass(frozen=True)
class TextureMappingInfo:
    texture_index: int
    s_vector: tuple[float, float, float, float]
    t_vector: tuple[float, float, float, float]
    flags: int


def clean_name(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "_" for ch in value)
    cleaned = "_".join(part for part in cleaned.split("_") if part)
    return cleaned or "unnamed"


def pad4(blob: bytearray) -> None:
    while len(blob) % 4:
        blob.append(0)


def add_buffer_view(blob: bytearray, payload: bytes, target: int | None = None) -> dict[str, int]:
    pad4(blob)
    offset = len(blob)
    blob.extend(payload)
    view: dict[str, int] = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
    if target is not None:
        view["target"] = target
    return view


def pack_floats(values: list[tuple[float, ...]]) -> bytes:
    flattened = [component for row in values for component in row]
    return struct.pack(f"<{len(flattened)}f", *flattened) if flattened else b""


def pack_indices(indices: list[int]) -> bytes:
    return struct.pack(f"<{len(indices)}I", *indices) if indices else b""


def read_c_string(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("ascii", errors="ignore")


def rgb565_to_rgba(pixel: int) -> tuple[int, int, int, int]:
    red = ((pixel >> 11) & 0x1F) * 255 // 31
    green = ((pixel >> 5) & 0x3F) * 255 // 63
    blue = (pixel & 0x1F) * 255 // 31
    return red, green, blue, 255


def decode_texture(
    data: bytes,
    offset: int,
    texture_dir: Path,
    source_stem: str,
    colliding_texture_names: set[str],
) -> TextureInfo:
    name = read_c_string(data[offset : offset + 16])
    width, height, _format_hint = struct.unpack_from("<3I", data, offset + 16)
    if width <= 0 or height <= 0:
        raise ValueError(f"invalid WMB texture dimensions for {name!r}: {width}x{height}")

    pixel_offset = offset + 40
    pixel_count = width * height
    image = Image.new("RGBA", (width, height))
    pixels = image.load()
    for index in range(pixel_count):
        value = struct.unpack_from("<H", data, pixel_offset + index * 2)[0]
        x = index % width
        y = index // width
        pixels[x, y] = rgb565_to_rgba(value)

    texture_name = clean_name(name)
    filename = f"{source_stem}_{texture_name}.png" if texture_name in colliding_texture_names else f"{texture_name}.png"
    image_path = texture_dir / filename
    image_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(image_path)
    return TextureInfo(name=name, filename=filename, width=width, height=height, image_path=image_path)


def decode_textures(data: bytes, texture_dir: Path, source_stem: str, colliding_texture_names: set[str]) -> list[TextureInfo]:
    words = struct.unpack_from("<32I", data, 0)
    texture_offset = words[5]
    texture_size = words[6]
    texture_count = struct.unpack_from("<I", data, texture_offset)[0]
    if texture_count <= 0 or texture_count > 16:
        raise ValueError(f"unexpected WMB texture count: {texture_count}")

    table_values = struct.unpack_from(f"<{texture_count}I", data, texture_offset + 4)
    textures: list[TextureInfo] = []
    for relative_offset in table_values:
        if relative_offset <= 0 or relative_offset >= texture_size:
            raise ValueError(f"invalid WMB texture offset: {relative_offset}")
        textures.append(decode_texture(data, texture_offset + relative_offset, texture_dir, source_stem, colliding_texture_names))
    return textures


def embedded_texture_hashes(source_path: Path) -> dict[str, set[str]]:
    data = source_path.read_bytes()
    words = struct.unpack_from("<32I", data, 0)
    texture_offset = words[5]
    texture_size = words[6]
    texture_count = struct.unpack_from("<I", data, texture_offset)[0]
    if texture_count <= 0 or texture_count > 16:
        raise ValueError(f"unexpected WMB texture count in {source_path}: {texture_count}")

    table_values = struct.unpack_from(f"<{texture_count}I", data, texture_offset + 4)
    hashes: dict[str, set[str]] = {}
    for relative_offset in table_values:
        if relative_offset <= 0 or relative_offset >= texture_size:
            raise ValueError(f"invalid WMB texture offset in {source_path}: {relative_offset}")
        offset = texture_offset + relative_offset
        name = clean_name(read_c_string(data[offset : offset + 16]))
        width, height, _format_hint = struct.unpack_from("<3I", data, offset + 16)
        payload = data[offset + 40 : offset + 40 + width * height * 2]
        if len(payload) != width * height * 2:
            raise ValueError(f"truncated WMB texture payload in {source_path}: {name}")
        hashes.setdefault(name, set()).add(hashlib.sha256(payload).hexdigest())
    return hashes


def find_colliding_texture_names(source_dir: Path, source_names: list[str]) -> set[str]:
    hashes_by_name: dict[str, set[str]] = {}
    for source_name in source_names:
        for texture_name, hashes in embedded_texture_hashes(source_dir / source_name).items():
            hashes_by_name.setdefault(texture_name, set()).update(hashes)
    return {texture_name for texture_name, hashes in hashes_by_name.items() if len(hashes) > 1}


def acknex_to_godot(position: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = position
    return (
        x * ACKNEX_TO_GODOT_SCALE,
        z * ACKNEX_TO_GODOT_SCALE,
        -y * ACKNEX_TO_GODOT_SCALE,
    )


def vector_sub(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vector_cross(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def vector_normalize(v: tuple[float, float, float]) -> tuple[float, float, float]:
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length <= 0.000001:
        return (0.0, 1.0, 0.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def polygon_normal(points: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    if len(points) < 3:
        return (0.0, 1.0, 0.0)
    base = points[0]
    for index in range(1, len(points) - 1):
        cross = vector_cross(vector_sub(points[index], base), vector_sub(points[index + 1], base))
        normal = vector_normalize(cross)
        if abs(normal[0]) + abs(normal[1]) + abs(normal[2]) > 0.000001:
            return normal
    return (0.0, 1.0, 0.0)


def planar_uv(point: tuple[float, float, float], points: list[tuple[float, float, float]], texture: TextureInfo) -> tuple[float, float]:
    ranges = [
        max(p[0] for p in points) - min(p[0] for p in points),
        max(p[1] for p in points) - min(p[1] for p in points),
        max(p[2] for p in points) - min(p[2] for p in points),
    ]
    axes = sorted(range(3), key=lambda axis: ranges[axis], reverse=True)[:2]
    if axes[1] == 1:
        axes = [axes[1], axes[0]]
    min_u = min(p[axes[0]] for p in points)
    min_v = min(p[axes[1]] for p in points)
    width = max(texture.width * ACKNEX_TO_GODOT_SCALE, 0.01)
    height = max(texture.height * ACKNEX_TO_GODOT_SCALE, 0.01)
    return ((point[axes[0]] - min_u) / width, 1.0 - ((point[axes[1]] - min_v) / height))


def mapped_uv(point: tuple[float, float, float], mapping: TextureMappingInfo, texture: TextureInfo) -> tuple[float, float]:
    s = (
        point[0] * mapping.s_vector[0]
        + point[1] * mapping.s_vector[1]
        + point[2] * mapping.s_vector[2]
        + mapping.s_vector[3]
    )
    t = (
        point[0] * mapping.t_vector[0]
        + point[1] * mapping.t_vector[1]
        + point[2] * mapping.t_vector[2]
        + mapping.t_vector[3]
    )
    return (s / max(texture.width, 1), t / max(texture.height, 1))


def apply_source_uv_fixups(
    source_name: str,
    texture: TextureInfo,
    polygon_uvs: list[tuple[float, float]],
) -> list[tuple[float, float]]:
    source_stem = clean_name(Path(source_name).stem)
    if source_stem == "teleport" and clean_name(texture.name) == "tileteleport2_b":
        texture_aspect = texture.height / max(texture.width, 1)
        return [(uv[0], uv[1] * texture_aspect) for uv in polygon_uvs]
    return polygon_uvs


def read_vertices(data: bytes) -> list[tuple[float, float, float]]:
    words = struct.unpack_from("<32I", data, 0)
    vertex_offset = words[7]
    vertex_count = words[8] // 12
    return [struct.unpack_from("<3f", data, vertex_offset + index * 12) for index in range(vertex_count)]


def read_texture_mappings(data: bytes, texture_count: int) -> list[TextureMappingInfo]:
    words = struct.unpack_from("<32I", data, 0)
    texinfo_offset = words[13]
    texinfo_count = words[14] // 64
    mappings: list[TextureMappingInfo] = []
    for index in range(texinfo_count):
        offset = texinfo_offset + index * 64
        values = struct.unpack_from("<16f", data, offset)
        ints = struct.unpack_from("<16i", data, offset)
        texture_index = ints[8]
        if texture_index < 0 or texture_index >= texture_count:
            texture_index = 0
        mappings.append(
            TextureMappingInfo(
                texture_index=texture_index,
                s_vector=values[0:4],
                t_vector=values[4:8],
                flags=ints[9],
            )
        )
    return mappings


def read_polygons(data: bytes) -> list[PolygonInfo]:
    words = struct.unpack_from("<32I", data, 0)
    polygon_offset = words[15]
    polygon_count = words[16] // 24
    ref_offset = words[27]
    ref_count = words[28] // 4
    edge_offset = words[25]
    edge_count = words[26] // 8
    edge_values = struct.unpack_from(f"<{edge_count * 2}I", data, edge_offset)
    edges = [edge_values[index : index + 2] for index in range(0, len(edge_values), 2)]
    refs = struct.unpack_from(f"<{ref_count}i", data, ref_offset)

    polygons: list[PolygonInfo] = []
    for index in range(polygon_count):
        record = struct.unpack_from("<12H", data, polygon_offset + index * 24)
        ref_start = record[2]
        vertex_count = record[4]
        vertices: list[int] = []
        for ref in refs[ref_start : ref_start + vertex_count]:
            edge = edges[abs(ref)]
            vertex = edge[0] if ref >= 0 else edge[1]
            if not vertices or vertices[-1] != vertex:
                vertices.append(vertex)
        if len(vertices) > 1 and vertices[0] == vertices[-1]:
            vertices.pop()
        if len(set(vertices)) < 3:
            vertices = []
            for ref in refs[ref_start : ref_start + vertex_count]:
                edge = edges[abs(ref)]
                directed = edge if ref >= 0 else (edge[1], edge[0])
                for vertex in directed:
                    if vertex not in vertices:
                        vertices.append(vertex)
        if len(set(vertices)) >= 3:
            polygons.append(
                PolygonInfo(
                    vertices=vertices,
                    field_side=record[1],
                    field_mapping=record[5],
                    plane_index=record[10],
                )
            )
    return polygons


def find_texture(textures: list[TextureInfo], *needles: str) -> int | None:
    for index, texture in enumerate(textures):
        name = texture.name.lower()
        if all(needle in name for needle in needles):
            return index
    return None


def choose_texture(
    textures: list[TextureInfo],
    source_name: str,
    polygon: PolygonInfo,
    acknex_points: list[tuple[float, float, float]],
) -> int:
    if len(textures) == 1:
        return 0

    source_stem = clean_name(Path(source_name).stem)
    texture_names = [texture.name.lower() for texture in textures]
    black = find_texture(textures, "black")
    if black is None:
        black = find_texture(textures, "dummy")
    lock = find_texture(textures, "lockgem")
    exit_text = find_texture(textures, "txt")
    wood = find_texture(textures, "wood")
    plank_back = next((i for i, name in enumerate(texture_names) if "plank" in name and "b_" in name), None)
    plank_main = next((i for i, name in enumerate(texture_names) if "plank" in name and i != plank_back and "txt" not in name), None)
    if plank_main is None:
        plank_main = next((i for i, name in enumerate(texture_names) if "plank" in name), None)

    mapping = polygon.field_mapping
    if source_stem.startswith("doorwk"):
        if black is not None and mapping in {0, 1, 2}:
            return black
        if wood is not None:
            return wood
        return black if black is not None else 0

    if source_stem == "doorexit":
        if exit_text is not None and mapping in {11, 12, 14}:
            return exit_text
        if black is not None and mapping in {0, 1, 2}:
            return black
        if plank_back is not None:
            return plank_back
        return 0

    if source_stem == "doordark":
        if plank_main is not None and mapping == 4:
            return plank_main
        if plank_back is not None and mapping in {3, 5, 7}:
            return plank_back
        return black if black is not None else 0

    if lock is not None and mapping in {10, 11, 15, 16, 17, 18, 19, 20, 21, 22}:
        return lock
    if mapping in {4, 5, 9, 13, 14}:
        if polygon.field_side == 1 and plank_back is not None:
            return plank_back
        if plank_main is not None:
            return plank_main
        if plank_back is not None:
            return plank_back
    if black is not None and mapping in {0, 1, 2, 3, 6, 7, 8, 12}:
        return black
    if plank_back is not None and (polygon.field_side == 1 or mapping in {4, 5, 9}):
        return plank_back
    if plank_main is not None:
        return plank_main

    xs = [point[0] for point in acknex_points]
    ys = [point[1] for point in acknex_points]
    zs = [point[2] for point in acknex_points]
    center_x = sum(xs) / len(xs)
    center_z = sum(zs) / len(zs)
    z_range = max(zs) - min(zs)
    y_range = max(ys) - min(ys)
    x_extent = max(abs(min(xs)), abs(max(xs)))

    if exit_text is not None and abs(center_x) < 80.0 and center_z > 70.0 and y_range <= 2.0:
        return exit_text
    if lock is not None and abs(center_x) < 78.0 and center_z > 58.0 and center_z < 262.0:
        return lock
    if black is not None and (center_z < 8.0 or center_z > 272.0 or x_extent > 126.0):
        return black
    if wood is not None:
        return wood
    if "doordark" in source_name and plank_main is not None and center_z > 40.0:
        return plank_main
    if plank_back is not None and (polygon.field_side == 1 or y_range > 20.0):
        return plank_back
    if plank_main is not None:
        return plank_main
    return 0


def choose_texture_mapping(
    texture_mappings: list[TextureMappingInfo],
    textures: list[TextureInfo],
    source_name: str,
    polygon: PolygonInfo,
    acknex_points: list[tuple[float, float, float]],
) -> TextureMappingInfo:
    if polygon.field_mapping >= 0 and polygon.field_mapping < len(texture_mappings):
        return texture_mappings[polygon.field_mapping]
    texture_index = choose_texture(textures, source_name, polygon, acknex_points)
    return TextureMappingInfo(
        texture_index=texture_index,
        s_vector=(1.0, 0.0, 0.0, 0.0),
        t_vector=(0.0, 0.0, -1.0, 0.0),
        flags=0,
    )


def write_gltf(
    source_name: str,
    output_dir: Path,
    textures: list[TextureInfo],
    positions: list[tuple[float, float, float]],
    normals: list[tuple[float, float, float]],
    uvs: list[tuple[float, float]],
    material_indices: dict[int, list[int]],
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = clean_name(Path(source_name).stem)
    blob = bytearray()
    buffer_views: list[dict[str, Any]] = []
    buffer_views.append(add_buffer_view(blob, pack_floats(positions), 34962))
    buffer_views.append(add_buffer_view(blob, pack_floats(normals), 34962))
    buffer_views.append(add_buffer_view(blob, pack_floats(uvs), 34962))

    used_material_indices = [index for index, indices in sorted(material_indices.items()) if indices]
    material_remap = {material_index: index for index, material_index in enumerate(used_material_indices)}

    primitive_index_views: dict[int, int] = {}
    for material_index in used_material_indices:
        indices = material_indices[material_index]
        if not indices:
            continue
        buffer_views.append(add_buffer_view(blob, pack_indices(indices), 34963))
        primitive_index_views[material_index] = len(buffer_views) - 1
    pad4(blob)

    bin_name = f"{stem}.bin"
    (output_dir / bin_name).write_bytes(blob)

    mins = [min(row[i] for row in positions) for i in range(3)]
    maxs = [max(row[i] for row in positions) for i in range(3)]
    accessors: list[dict[str, Any]] = [
        {
            "bufferView": 0,
            "componentType": 5126,
            "count": len(positions),
            "type": "VEC3",
            "min": mins,
            "max": maxs,
        },
        {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": len(uvs), "type": "VEC2"},
    ]

    index_accessor_by_material: dict[int, int] = {}
    for material_index, view_index in primitive_index_views.items():
        indices = material_indices[material_index]
        index_accessor_by_material[material_index] = len(accessors)
        accessors.append(
            {
                "bufferView": view_index,
                "componentType": 5125,
                "count": len(indices),
                "type": "SCALAR",
                "min": [min(indices)],
                "max": [max(indices)],
            }
        )

    primitives = [
        {
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": accessor_index,
            "material": material_remap[material_index],
        }
        for material_index, accessor_index in sorted(index_accessor_by_material.items())
    ]

    materials = []
    for material_index in used_material_indices:
        texture = textures[material_index]
        materials.append(
            {
                "name": clean_name(texture.name),
                "doubleSided": True,
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": material_remap[material_index]},
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
            }
        )
    images = [
        {"uri": os.path.relpath(textures[material_index].image_path, output_dir).replace(os.sep, "/")}
        for material_index in used_material_indices
    ]
    gltf = {
        "asset": {"version": "2.0", "generator": "convert_gate_wmb_models.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": stem}],
        "meshes": [{"name": stem, "primitives": primitives}],
        "materials": materials,
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "textures": [{"source": index, "sampler": 0} for index in range(len(used_material_indices))],
        "images": images,
        "buffers": [{"uri": bin_name, "byteLength": len(blob)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
    }
    if stem == "teleport":
        gltf["extras"] = {"uv_fixups": ["tileteleport2_b_single_vertical_repeat"]}
    gltf_path = output_dir / f"{stem}.gltf"
    gltf_path.write_text(json.dumps(gltf, indent=2), encoding="utf-8")
    return gltf_path


def polygon_triangle_indices(polygon_indices: list[int], points: list[tuple[float, float, float]]) -> list[int]:
    indices: list[int] = []
    for index in range(1, len(polygon_indices) - 1):
        triangle = [polygon_indices[0], polygon_indices[index], polygon_indices[index + 1]]
        triangle_points = [points[0], points[index], points[index + 1]]
        normal = polygon_normal(triangle_points)
        if abs(normal[0]) + abs(normal[1]) + abs(normal[2]) <= 0.000001:
            continue
        indices.extend(triangle)
    return indices


def convert_wmb(source_path: Path, model_root: Path, texture_root: Path, colliding_texture_names: set[str]) -> dict[str, Any]:
    data = source_path.read_bytes()
    if len(data) < 0x80 or data[:4] != WMB_MAGIC:
        raise ValueError(f"{source_path} is not a WMB4 file")

    words = struct.unpack_from("<32I", data, 0)
    source_polygon_count = words[16] // 24
    stem = clean_name(source_path.stem)
    textures = decode_textures(data, texture_root, stem, colliding_texture_names)
    texture_mappings = read_texture_mappings(data, len(textures))
    acknex_vertices = read_vertices(data)
    polygons = read_polygons(data)

    positions: list[tuple[float, float, float]] = []
    normals: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    material_indices: dict[int, list[int]] = {index: [] for index in range(len(textures))}
    used_texture_indices: set[int] = set()
    emitted_polygon_count = 0
    emitted_triangle_count = 0
    skipped_no_render_polygon_count = 0

    for polygon in polygons:
        acknex_points = [acknex_vertices[index] for index in polygon.vertices]
        godot_points = [acknex_to_godot(point) for point in acknex_points]
        texture_mapping = choose_texture_mapping(
            texture_mappings,
            textures,
            source_path.name.lower(),
            polygon,
            acknex_points,
        )
        if (texture_mapping.flags & TEXINFO_NO_RENDER_FLAG) != 0:
            skipped_no_render_polygon_count += 1
            continue
        material_index = texture_mapping.texture_index
        texture = textures[material_index]
        normal = polygon_normal(godot_points)
        polygon_indices: list[int] = []
        polygon_uvs = [
            mapped_uv(acknex_points[point_index], texture_mapping, texture)
            for point_index in range(len(godot_points))
        ]
        polygon_uvs = apply_source_uv_fixups(source_path.name.lower(), texture, polygon_uvs)
        for point_index, point in enumerate(godot_points):
            polygon_indices.append(len(positions))
            positions.append(point)
            normals.append(normal)
            uvs.append(polygon_uvs[point_index])
        triangle_indices = polygon_triangle_indices(polygon_indices, godot_points)
        if triangle_indices:
            emitted_polygon_count += 1
            emitted_triangle_count += len(triangle_indices) // 3
            used_texture_indices.add(material_index)
            material_indices[material_index].extend(triangle_indices)

    gltf_path = write_gltf(source_path.name, model_root / stem, textures, positions, normals, uvs, material_indices)
    return {
        "source": source_path.as_posix(),
        "output": gltf_path.as_posix(),
        "texture_count": len(textures),
        "texture_mapping_count": len(texture_mappings),
        "mapping_source": "wmb_texinfo",
        "source_polygon_count": source_polygon_count,
        "polygon_count": emitted_polygon_count,
        "triangle_count": emitted_triangle_count,
        "skipped_polygon_count": max(source_polygon_count - emitted_polygon_count, 0),
        "skipped_no_render_polygon_count": skipped_no_render_polygon_count,
        "used_textures": [textures[index].name for index in sorted(used_texture_indices)],
        "texture_files": [texture.filename for texture in textures],
        "vertex_count": len(positions),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("extract-sammy-assets/extracted/godot/raw/levels"),
    )
    parser.add_argument("--model-root", type=Path, default=Path("assets/models/gates"))
    parser.add_argument("--texture-root", type=Path, default=Path("assets/textures/gates"))
    parser.add_argument("--manifest-name", default="gate_wmb_manifest.json")
    parser.add_argument("--source-names", nargs="+", default=SOURCE_WMB_NAMES)
    args = parser.parse_args()

    source_names = [str(name) for name in args.source_names]
    colliding_texture_names = find_colliding_texture_names(args.source_dir, source_names)
    converted: list[dict[str, Any]] = []
    for name in source_names:
        source_path = args.source_dir / name
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        converted.append(convert_wmb(source_path, args.model_root, args.texture_root, colliding_texture_names))

    manifest_path = args.model_root / args.manifest_name
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps({"converted": converted}, indent=2) + "\n", encoding="utf-8")
    print(f"converted {len(converted)} WMB models")
    print(f"manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
