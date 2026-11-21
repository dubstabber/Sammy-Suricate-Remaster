#!/usr/bin/env python3
"""Convert original Sammy Suricate WMB4 levels into Godot-friendly assets.

Per level this writes, under `assets/levels/<stem>/`:

- `<stem>.gltf` + `.bin`: a `<stem>_render` node (visible faces, one primitive
  per texture) and a `<stem>_collision-colonly` node (every face, including
  no-render clip faces). Godot's importer turns the `-colonly` node into a
  StaticBody3D with trimesh collision on the default "world" layer.
- `<stem>_entities.json`: decoded objects (entities, lights, sun, positions)
  with Godot-space positions and a precomputed WDL-style ground trace.

Level textures go to the shared `assets/textures/levels/` directory. A texture
name that maps to different pixels in different levels gets a `_<sha8>` suffix;
the collision set is always computed over every convertible level so names stay
stable no matter which subset is converted.

Source files (read-only): the Polish install for the 36 shared levels and the
English v1.4 install for bonus 1-4.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import struct
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import wmb4  # noqa: E402

ACKNEX_TO_GODOT_SCALE = 0.01
POLISH_DIR = Path("extract-sammy-assets/sammy-suricate")
ENGLISH_DIR = Path("extract-sammy-assets/sammy-suricate-eng")
EXTRACTED_TEXTURE_DIR = Path("extract-sammy-assets/extracted/godot/textures")
LEVEL_ROOT = Path("assets/levels")
LEVEL_TEXTURE_ROOT = Path("assets/textures/levels")
SPRITE_TEXTURE_ROOT = Path("assets/textures/sprites")
LEVEL_MANIFEST_NAME = "level_manifest.json"

# Loads.wdl InitLevel1..48 level files (Polish build) plus the English-only bonus levels.
POLISH_LEVEL_FILES = [
    "10001.wmb", "10002.wmb", "10003.wmb", "10004.wmb", "10005.wmb", "10006.wmb",
    "10007.wmb", "10008.wmb", "10009.wmb", "10010.wmb", "10011.wmb", "10012.wmb",
    "101o_j.wmb", "102N_t.wmb", "103J_j.wmb", "104M_j.wmb", "106g_t.wmb", "107i_j.wmb",
    "108i_j.wmb", "109o_t.wmb", "110n_t.wmb", "111r_j.wmb", "112e_j.wmb", "113q_t.wmb",
    "114t_t.wmb", "170b_t00.wmb", "171c_t04.wmb", "172c_j06.wmb", "173b_t05.wmb",
    "174a_j07.wmb", "175c_t.wmb", "176g_t.wmb", "177e_j.wmb", "178d_t.wmb", "179f_t.wmb",
    "180c_t.wmb",
]
ENGLISH_BONUS_FILES = ["bonus1.wmb", "bonus2.wmb", "bonus3.wmb", "bonus4.wmb"]
OPTIONAL_LEVEL_FILES = {"extro": POLISH_DIR / "extro.wmb"}

# Entities the Godot builder renders as standalone sprites (WDL InitArbre/OnGround,
# and action-less sprites).
SPRITE_FILE_SUFFIX = ".pcx"
SPRITE_ACTIONS = {"initarbre", "onground", ""}
# WDL traces ignore models/sprites/passable entities, so only level faces whose
# front normal points up count as ground (Acknex z is up).
GROUND_NORMAL_MIN_Z = 0.3
GROUND_TRACE_DEPTH = 4000.0
GROUND_TRACE_START_EPSILON = 1.0
GROUND_GRID_CELL = 256.0


def clean_name(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "_" for ch in value)
    cleaned = "_".join(part for part in cleaned.split("_") if part)
    return cleaned or "unnamed"


def level_stem(file_name: str) -> str:
    return clean_name(Path(file_name).stem)


def level_sources(repo_root: Path) -> dict[str, tuple[Path, str]]:
    sources: dict[str, tuple[Path, str]] = {}
    for name in POLISH_LEVEL_FILES:
        sources[level_stem(name)] = (repo_root / POLISH_DIR / name, "polish")
    for name in ENGLISH_BONUS_FILES:
        sources[level_stem(name)] = (repo_root / ENGLISH_DIR / name, "english")
    return sources


def optional_sources(repo_root: Path) -> dict[str, tuple[Path, str]]:
    return {stem: (repo_root / path, "polish") for stem, path in OPTIONAL_LEVEL_FILES.items()}


def acknex_to_godot(point: tuple[float, float, float] | list[float]) -> tuple[float, float, float]:
    x, y, z = point
    return (x * ACKNEX_TO_GODOT_SCALE, z * ACKNEX_TO_GODOT_SCALE, -y * ACKNEX_TO_GODOT_SCALE)


def acknex_direction_to_godot(vector: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = vector
    return (x, z, -y)


def rounded(values: tuple[float, ...] | list[float], digits: int = 5) -> list[float]:
    return [round(float(value), digits) for value in values]


# --- textures -----------------------------------------------------------------


def compute_colliding_texture_names(paths: list[Path]) -> set[str]:
    hashes: dict[str, set[str]] = {}
    for path in paths:
        data = path.read_bytes()
        for record in wmb4.read_texture_records(data):
            hashes.setdefault(clean_name(record.name), set()).add(wmb4.texture_payload_hash(data, record))
    return {name for name, values in hashes.items() if len(values) > 1}


def texture_file_name(data: bytes, record: wmb4.TextureRecord, colliding: set[str]) -> str:
    name = clean_name(record.name)
    if name in colliding:
        name = f"{name}_{wmb4.texture_payload_hash(data, record)[:8]}"
    return f"{name}.png"


def write_texture(data: bytes, record: wmb4.TextureRecord, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    wmb4.texture_image(data, record).save(path)


# --- geometry -----------------------------------------------------------------


@dataclass
class LevelFace:
    index: int
    acknex_points: list[tuple[float, float, float]]
    front_normal: tuple[float, float, float]
    plane_normal: tuple[float, float, float]
    plane_distance: float
    texinfo: wmb4.TexInfo
    renders: bool


def front_winding(face: wmb4.Face, edges: list[tuple[int, int]], surfedges: list[int]) -> list[int]:
    # WMB4 windings are clockwise seen from the front; glTF wants counter-clockwise.
    vertices = wmb4.face_edge_vertices(face, edges, surfedges)
    vertices.reverse()
    return vertices


def read_level_faces(data: bytes) -> list[LevelFace]:
    planes = wmb4.read_planes(data)
    vertices = wmb4.read_vertices(data)
    edges = wmb4.read_edges(data)
    surfedges = wmb4.read_surfedges(data)
    texinfos = wmb4.read_texinfos(data)
    faces: list[LevelFace] = []
    for index, face in enumerate(wmb4.read_faces(data)):
        winding = front_winding(face, edges, surfedges)
        if len(set(winding)) < 3:
            continue
        plane = planes[face.plane_index]
        sign = -1.0 if face.side else 1.0
        texinfo = texinfos[face.texinfo_index]
        faces.append(
            LevelFace(
                index=index,
                acknex_points=[vertices[vertex] for vertex in winding],
                front_normal=(plane.normal[0] * sign, plane.normal[1] * sign, plane.normal[2] * sign),
                plane_normal=plane.normal,
                plane_distance=plane.distance,
                texinfo=texinfo,
                renders=(texinfo.flags & wmb4.TEXINFO_NO_RENDER_FLAG) == 0,
            )
        )
    return faces


def triangle_area_ok(a: tuple[float, float, float], b: tuple[float, float, float], c: tuple[float, float, float]) -> bool:
    ab = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    ac = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    cross = (ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2], ab[0] * ac[1] - ab[1] * ac[0])
    return cross[0] * cross[0] + cross[1] * cross[1] + cross[2] * cross[2] > 1e-6


def fan_triangles(base: int, points: list[tuple[float, float, float]]) -> list[int]:
    indices: list[int] = []
    for index in range(1, len(points) - 1):
        if triangle_area_ok(points[0], points[index], points[index + 1]):
            indices.extend([base, base + index, base + index + 1])
    return indices


def texinfo_uv(point: tuple[float, float, float], texinfo: wmb4.TexInfo, width: int, height: int) -> tuple[float, float]:
    s, t = wmb4.texinfo_st(point, texinfo)
    return (s / max(width, 1), t / max(height, 1))


# --- glTF ---------------------------------------------------------------------


class GltfBuffer:
    def __init__(self) -> None:
        self.blob = bytearray()
        self.views: list[dict[str, Any]] = []
        self.accessors: list[dict[str, Any]] = []

    def _view(self, payload: bytes, target: int) -> int:
        while len(self.blob) % 4:
            self.blob.append(0)
        self.views.append({"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(payload), "target": target})
        self.blob.extend(payload)
        return len(self.views) - 1

    def vec_accessor(self, rows: list[tuple[float, ...]], kind: str, with_bounds: bool = False) -> int:
        flattened = [component for row in rows for component in row]
        view = self._view(struct.pack(f"<{len(flattened)}f", *flattened), 34962)
        accessor: dict[str, Any] = {"bufferView": view, "componentType": 5126, "count": len(rows), "type": kind}
        if with_bounds:
            width = len(rows[0])
            accessor["min"] = [min(row[i] for row in rows) for i in range(width)]
            accessor["max"] = [max(row[i] for row in rows) for i in range(width)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def index_accessor(self, indices: list[int]) -> int:
        view = self._view(struct.pack(f"<{len(indices)}I", *indices), 34963)
        self.accessors.append(
            {"bufferView": view, "componentType": 5125, "count": len(indices), "type": "SCALAR", "min": [min(indices)], "max": [max(indices)]}
        )
        return len(self.accessors) - 1


def build_level_gltf(
    stem: str,
    faces: list[LevelFace],
    textures: list[wmb4.TextureRecord],
    texture_files: list[str],
    output_dir: Path,
    texture_root: Path,
) -> dict[str, Any]:
    gltf_buffer = GltfBuffer()

    positions: list[tuple[float, float, float]] = []
    normals: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    indices_by_texture: dict[int, list[int]] = {}
    render_face_count = 0
    for face in faces:
        if not face.renders:
            continue
        texture_index = face.texinfo.texture_index if 0 <= face.texinfo.texture_index < len(textures) else 0
        texture = textures[texture_index]
        godot_points = [acknex_to_godot(point) for point in face.acknex_points]
        normal = acknex_direction_to_godot(face.front_normal)
        base = len(positions)
        triangles = fan_triangles(base, godot_points)
        if not triangles:
            continue
        for point_index, point in enumerate(godot_points):
            positions.append(point)
            normals.append(normal)
            uvs.append(texinfo_uv(face.acknex_points[point_index], face.texinfo, texture.width, texture.height))
        indices_by_texture.setdefault(texture_index, []).extend(triangles)
        render_face_count += 1

    collision_positions: list[tuple[float, float, float]] = []
    collision_indices: list[int] = []
    for face in faces:
        godot_points = [acknex_to_godot(point) for point in face.acknex_points]
        triangles = fan_triangles(len(collision_positions), godot_points)
        if not triangles:
            continue
        collision_positions.extend(godot_points)
        collision_indices.extend(triangles)

    meshes: list[dict[str, Any]] = []
    nodes: list[dict[str, Any]] = []
    materials: list[dict[str, Any]] = []
    images: list[dict[str, Any]] = []
    gltf_textures: list[dict[str, Any]] = []
    used_textures = sorted(indices_by_texture)
    if positions:
        position_accessor = gltf_buffer.vec_accessor(positions, "VEC3", with_bounds=True)
        normal_accessor = gltf_buffer.vec_accessor(normals, "VEC3")
        uv_accessor = gltf_buffer.vec_accessor(uvs, "VEC2")
        primitives = []
        for material_index, texture_index in enumerate(used_textures):
            primitives.append(
                {
                    "attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor, "TEXCOORD_0": uv_accessor},
                    "indices": gltf_buffer.index_accessor(indices_by_texture[texture_index]),
                    "material": material_index,
                }
            )
            image_path = texture_root / texture_files[texture_index]
            images.append({"uri": os.path.relpath(image_path, output_dir).replace(os.sep, "/")})
            gltf_textures.append({"source": material_index, "sampler": 0})
            materials.append(
                {
                    "name": Path(texture_files[texture_index]).stem,
                    "doubleSided": False,
                    "pbrMetallicRoughness": {
                        "baseColorTexture": {"index": material_index},
                        "metallicFactor": 0.0,
                        "roughnessFactor": 1.0,
                    },
                }
            )
        meshes.append({"name": f"{stem}_render", "primitives": primitives})
        nodes.append({"name": f"{stem}_render", "mesh": len(meshes) - 1})

    if collision_positions:
        collision_accessor = gltf_buffer.vec_accessor(collision_positions, "VEC3", with_bounds=True)
        meshes.append(
            {
                "name": f"{stem}_collision",
                "primitives": [{"attributes": {"POSITION": collision_accessor}, "indices": gltf_buffer.index_accessor(collision_indices)}],
            }
        )
        nodes.append({"name": f"{stem}_collision-colonly", "mesh": len(meshes) - 1})

    while len(gltf_buffer.blob) % 4:
        gltf_buffer.blob.append(0)
    output_dir.mkdir(parents=True, exist_ok=True)
    bin_name = f"{stem}.bin"
    (output_dir / bin_name).write_bytes(gltf_buffer.blob)
    gltf: dict[str, Any] = {
        "asset": {"version": "2.0", "generator": "convert_level_wmb.py"},
        "scene": 0,
        "scenes": [{"name": stem, "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "buffers": [{"uri": bin_name, "byteLength": len(gltf_buffer.blob)}],
        "bufferViews": gltf_buffer.views,
        "accessors": gltf_buffer.accessors,
    }
    if materials:
        gltf["materials"] = materials
        gltf["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
        gltf["textures"] = gltf_textures
        gltf["images"] = images
    gltf_path = output_dir / f"{stem}.gltf"
    gltf_path.write_text(json.dumps(gltf, indent=1) + "\n", encoding="utf-8")

    bounds_min = [min(point[i] for point in collision_positions) for i in range(3)] if collision_positions else [0.0, 0.0, 0.0]
    bounds_max = [max(point[i] for point in collision_positions) for i in range(3)] if collision_positions else [0.0, 0.0, 0.0]
    return {
        "gltf_path": gltf_path,
        "render_face_count": render_face_count,
        "render_triangle_count": sum(len(values) for values in indices_by_texture.values()) // 3,
        "collision_triangle_count": len(collision_indices) // 3,
        "used_texture_files": [texture_files[index] for index in used_textures],
        "bounds_min": rounded(bounds_min),
        "bounds_max": rounded(bounds_max),
    }


# --- ground trace -----------------------------------------------------------------


@dataclass
class GroundFace:
    points_xy: list[tuple[float, float]]
    normal: tuple[float, float, float]
    distance: float
    min_x: float
    max_x: float
    min_y: float
    max_y: float


class GroundTracer:
    """Downward WDL-style trace against level faces that face up."""

    def __init__(self, faces: list[LevelFace]) -> None:
        self._cells: dict[tuple[int, int], list[GroundFace]] = {}
        for face in faces:
            if face.front_normal[2] < GROUND_NORMAL_MIN_Z:
                continue
            xs = [point[0] for point in face.acknex_points]
            ys = [point[1] for point in face.acknex_points]
            ground_face = GroundFace(
                points_xy=[(point[0], point[1]) for point in face.acknex_points],
                normal=face.plane_normal,
                distance=face.plane_distance,
                min_x=min(xs),
                max_x=max(xs),
                min_y=min(ys),
                max_y=max(ys),
            )
            for cell_x in range(math.floor(ground_face.min_x / GROUND_GRID_CELL), math.floor(ground_face.max_x / GROUND_GRID_CELL) + 1):
                for cell_y in range(math.floor(ground_face.min_y / GROUND_GRID_CELL), math.floor(ground_face.max_y / GROUND_GRID_CELL) + 1):
                    self._cells.setdefault((cell_x, cell_y), []).append(ground_face)

    @staticmethod
    def _contains(face: GroundFace, x: float, y: float) -> bool:
        if x < face.min_x - 0.01 or x > face.max_x + 0.01 or y < face.min_y - 0.01 or y > face.max_y + 0.01:
            return False
        sign = 0.0
        points = face.points_xy
        for index, (ax, ay) in enumerate(points):
            bx, by = points[(index + 1) % len(points)]
            cross = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
            if abs(cross) < 1e-6:
                continue
            if sign == 0.0:
                sign = cross
            elif (cross > 0.0) != (sign > 0.0):
                return False
        return True

    def trace(self, position: list[float] | tuple[float, float, float]) -> float | None:
        x, y, z = position
        cell = (math.floor(x / GROUND_GRID_CELL), math.floor(y / GROUND_GRID_CELL))
        best: float | None = None
        for face in self._cells.get(cell, []):
            if not self._contains(face, x, y) or abs(face.normal[2]) < 1e-6:
                continue
            hit_z = (face.distance - face.normal[0] * x - face.normal[1] * y) / face.normal[2]
            if hit_z > z + GROUND_TRACE_START_EPSILON or hit_z < z - GROUND_TRACE_DEPTH:
                continue
            if best is None or hit_z > best:
                best = hit_z
        return best


# --- entities -----------------------------------------------------------------


def build_entity_records(objects: list[dict[str, Any]], tracer: GroundTracer) -> dict[str, Any]:
    entities: list[dict[str, Any]] = []
    lights: list[dict[str, Any]] = []
    positions: list[dict[str, Any]] = []
    sun: dict[str, Any] | None = None
    unknown: list[dict[str, Any]] = []
    for record in objects:
        object_type = int(record["type"])
        if object_type == wmb4.OBJECT_TYPE_ENTITY:
            ground_z = tracer.trace(record["position"])
            entities.append(
                {
                    "index": record["index"],
                    "name": record["name"],
                    "file": record["file"],
                    "action": record["action"].lower(),
                    "action_source": record["action"],
                    "position": rounded(record["position"], 4),
                    "angles": rounded(record["angles"], 4),
                    "scale": rounded(record["scale"], 4),
                    "skills": rounded(record["skills"], 5),
                    "flags": record["flags"],
                    "extra_0x84": round(record["extra_0x84"], 4),
                    "godot_position": rounded(acknex_to_godot(record["position"])),
                    "ground_z": None if ground_z is None else round(ground_z, 4),
                    "godot_ground_y": None if ground_z is None else round(ground_z * ACKNEX_TO_GODOT_SCALE, 5),
                }
            )
        elif object_type == wmb4.OBJECT_TYPE_LIGHT:
            lights.append(
                {
                    "index": record["index"],
                    "position": rounded(record["position"], 4),
                    "godot_position": rounded(acknex_to_godot(record["position"])),
                    "color_percent": rounded(record["color_percent"], 4),
                    "range": round(record["range"], 4),
                }
            )
        elif object_type == wmb4.OBJECT_TYPE_SUN:
            sun = {"index": record["index"], "pan": round(record["pan"], 4), "tilt": round(record["tilt"], 4)}
        elif object_type == wmb4.OBJECT_TYPE_POSITION:
            positions.append(
                {
                    "index": record["index"],
                    "name": record["name"],
                    "position": rounded(record["position"], 4),
                    "angles": rounded(record["angles"], 4),
                    "godot_position": rounded(acknex_to_godot(record["position"])),
                }
            )
        else:
            unknown.append(record)
    return {"entities": entities, "lights": lights, "sun": sun, "positions": positions, "unknown_objects": unknown}


def copy_sprite_textures(repo_root: Path, entities: list[dict[str, Any]], sprite_root: Path) -> list[str]:
    copied: list[str] = []
    for entity in entities:
        file_name = str(entity["file"])
        if entity["action"] not in SPRITE_ACTIONS or not file_name.lower().endswith(SPRITE_FILE_SUFFIX):
            continue
        source = find_extracted_texture(repo_root, Path(file_name).stem)
        if source is None:
            continue
        target = sprite_root / f"{clean_sprite_name(file_name)}.png"
        if target.name in copied:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copyfile(source, target)
        copied.append(target.name)
    return sorted(copied)


def clean_sprite_name(file_name: str) -> str:
    return clean_name(Path(file_name).stem)


def find_extracted_texture(repo_root: Path, stem: str) -> Path | None:
    directory = repo_root / EXTRACTED_TEXTURE_DIR
    exact = directory / f"{stem}.png"
    if exact.exists():
        return exact
    lowered = stem.lower()
    for candidate in directory.glob("*.png"):
        if candidate.stem.lower() == lowered:
            return candidate
    return None


# --- driver -------------------------------------------------------------------


def convert_level(
    repo_root: Path,
    stem: str,
    source_path: Path,
    source_build: str,
    colliding: set[str],
    sprite_texture_names: set[str],
) -> dict[str, Any]:
    data = source_path.read_bytes()
    textures = wmb4.read_texture_records(data)
    texture_files = [texture_file_name(data, record, colliding) for record in textures]
    texture_root = repo_root / LEVEL_TEXTURE_ROOT
    for record, file_name in zip(textures, texture_files):
        write_texture(data, record, texture_root / file_name)

    faces = read_level_faces(data)
    output_dir = repo_root / LEVEL_ROOT / stem
    geometry = build_level_gltf(stem, faces, textures, texture_files, output_dir, texture_root)
    objects = wmb4.read_objects(data)
    records = build_entity_records(objects, GroundTracer(faces))
    sprite_files = copy_sprite_textures(repo_root, records["entities"], repo_root / SPRITE_TEXTURE_ROOT)
    sprite_texture_names.update(sprite_files)

    action_counts = Counter(entity["action"] for entity in records["entities"])
    payload = {
        "stem": stem,
        "source": source_path.relative_to(repo_root).as_posix(),
        "source_build": source_build,
        "format": "WMB4",
        "acknex_to_godot_scale": ACKNEX_TO_GODOT_SCALE,
        "geometry": {
            "gltf": geometry["gltf_path"].relative_to(repo_root).as_posix(),
            "face_count": len(faces),
            "render_face_count": geometry["render_face_count"],
            "render_triangle_count": geometry["render_triangle_count"],
            "collision_triangle_count": geometry["collision_triangle_count"],
            "textures": texture_files,
            "used_textures": geometry["used_texture_files"],
            "godot_bounds_min": geometry["bounds_min"],
            "godot_bounds_max": geometry["bounds_max"],
        },
        "sun": records["sun"],
        "lights": records["lights"],
        "positions": records["positions"],
        "action_counts": dict(sorted(action_counts.items())),
        "sprite_textures": sprite_files,
        "entities": records["entities"],
    }
    if records["unknown_objects"]:
        payload["unknown_objects"] = records["unknown_objects"]
    entities_path = output_dir / f"{stem}_entities.json"
    entities_path.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")
    return {
        "stem": stem,
        "source": payload["source"],
        "source_build": source_build,
        "gltf": payload["geometry"]["gltf"],
        "entities": entities_path.relative_to(repo_root).as_posix(),
        "entity_count": len(records["entities"]),
        "face_count": len(faces),
        "texture_count": len(textures),
    }


def update_manifest(repo_root: Path, converted: list[dict[str, Any]]) -> Path:
    manifest_path = repo_root / LEVEL_ROOT / LEVEL_MANIFEST_NAME
    existing: dict[str, dict[str, Any]] = {}
    if manifest_path.exists():
        for entry in json.loads(manifest_path.read_text(encoding="utf-8")).get("levels", []):
            existing[str(entry["stem"])] = entry
    for entry in converted:
        existing[str(entry["stem"])] = entry
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    levels = [existing[stem] for stem in sorted(existing)]
    manifest_path.write_text(json.dumps({"levels": levels}, indent=2) + "\n", encoding="utf-8")
    return manifest_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--levels", nargs="+", help="level stems, e.g. 10001 101o_j bonus1")
    group.add_argument("--all", action="store_true", help="convert every catalog level (36 Polish + 4 English bonus)")
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()

    sources = level_sources(repo_root)
    available = {**sources, **optional_sources(repo_root)}
    stems = sorted(sources) if args.all else [level_stem(name) for name in args.levels]
    missing = [stem for stem in stems if stem not in available]
    if missing:
        parser.error(f"unknown level stems: {', '.join(missing)}")

    collision_paths = [path for path, _build in available.values() if path.exists()]
    colliding = compute_colliding_texture_names(collision_paths)
    converted: list[dict[str, Any]] = []
    sprite_names: set[str] = set()
    for stem in stems:
        source_path, source_build = available[stem]
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        result = convert_level(repo_root, stem, source_path, source_build, colliding, sprite_names)
        converted.append(result)
        print(f"{stem}: {result['face_count']} faces, {result['texture_count']} textures, {result['entity_count']} entities")
    manifest_path = update_manifest(repo_root, converted)
    print(f"sprite textures: {', '.join(sorted(sprite_names)) or 'none'}")
    print(f"manifest: {manifest_path.relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
