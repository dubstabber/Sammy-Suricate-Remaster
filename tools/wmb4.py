#!/usr/bin/env python3
"""Shared Acknex A5 WMB4 parsing helpers.

WMB4 starts with the "WMB4" magic followed by 16 (offset, length) u32 pairs.
The list order mirrors Quake BSP29 lumps. Only the lists the remaster needs
are decoded here; everything else stays accessible through `read_header`.

Coordinates are returned in Acknex space (x, y, z with z up, quants).
"""

from __future__ import annotations

import hashlib
import math
import struct
from dataclasses import dataclass
from typing import Any

from PIL import Image

WMB_MAGIC = b"WMB4"
HEADER_LIST_COUNT = 16

LIST_UNKNOWN_0 = 0
LIST_PLANES = 1
LIST_TEXTURES = 2
LIST_VERTICES = 3
LIST_VISIBILITY = 4
LIST_NODES = 5
LIST_TEXINFO = 6
LIST_FACES = 7
LIST_LIGHTMAPS = 8
LIST_CLIPNODES = 9
LIST_LEAVES = 10
LIST_MARKSURFACES = 11
LIST_EDGES = 12
LIST_SURFEDGES = 13
LIST_MODELS = 14
LIST_OBJECTS = 15

PLANE_SIZE = 20
VERTEX_SIZE = 12
TEXINFO_SIZE = 64
FACE_SIZE = 24
EDGE_SIZE = 8
SURFEDGE_SIZE = 4

TEXINFO_NO_RENDER_FLAG = 0x8
NO_LIGHTMAP = 0xFFFFFFFF
LIGHTMAP_BLOCK_SIZE = 16

OBJECT_TYPE_POSITION = 1
OBJECT_TYPE_LIGHT = 2
OBJECT_TYPE_ENTITY = 3
OBJECT_TYPE_SUN = 5
ENTITY_SKILL_COUNT = 8


@dataclass(frozen=True)
class ListEntry:
    offset: int
    length: int


@dataclass(frozen=True)
class Plane:
    normal: tuple[float, float, float]
    distance: float
    plane_type: int


@dataclass(frozen=True)
class TexInfo:
    s_vector: tuple[float, float, float, float]
    t_vector: tuple[float, float, float, float]
    texture_index: int
    flags: int


@dataclass(frozen=True)
class Face:
    """24-byte WMB4 face record.

    Byte 20 holds the plane index (verified: every face of 10001/101o_j lies on
    that plane). Windings are clockwise when viewed from the front side; the
    front normal is the plane normal, negated when `side` is 1.
    """

    unknown_0: int
    side: int
    first_edge: int
    edge_count: int
    texinfo_index: int
    styles: tuple[int, int, int, int]
    light_offset: int
    plane_index: int
    unknown_22: int


@dataclass(frozen=True)
class TextureRecord:
    name: str
    width: int
    height: int
    format_hint: int
    offset: int

    @property
    def pixel_offset(self) -> int:
        return self.offset + 40

    @property
    def payload_size(self) -> int:
        return self.width * self.height * 2


def read_c_string(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("ascii", errors="ignore")


def read_header(data: bytes) -> list[ListEntry]:
    if len(data) < 4 + HEADER_LIST_COUNT * 8 or data[:4] != WMB_MAGIC:
        raise ValueError("not a WMB4 file")
    words = struct.unpack_from(f"<{HEADER_LIST_COUNT * 2}I", data, 4)
    entries = [ListEntry(words[index * 2], words[index * 2 + 1]) for index in range(HEADER_LIST_COUNT)]
    for index, entry in enumerate(entries):
        if entry.length and entry.offset + entry.length > len(data):
            raise ValueError(f"WMB4 list {index} exceeds file size")
    return entries


def list_entry(data: bytes, list_index: int) -> ListEntry:
    return read_header(data)[list_index]


def read_planes(data: bytes) -> list[Plane]:
    entry = list_entry(data, LIST_PLANES)
    planes: list[Plane] = []
    for index in range(entry.length // PLANE_SIZE):
        nx, ny, nz, distance, plane_type = struct.unpack_from("<4fi", data, entry.offset + index * PLANE_SIZE)
        planes.append(Plane(normal=(nx, ny, nz), distance=distance, plane_type=plane_type))
    return planes


# BSP point hull (nodes + leaves). A node is 40 bytes: plane index, parent
# pointer, int16 bounds, an unused int, the two child indices (negative =
# leaf -(index + 1)) and its face range. A leaf is 36 bytes starting with its
# contents: -128 is solid (only leaf 0), -256 empty. Space outside the level is
# empty (A5 levels are not sealed).
NODE_SIZE = 40
LEAF_SIZE = 36
CONTENTS_SOLID = -128
CONTENTS_EMPTY = -256


class BspTree:
    """Point contents of the level BSP (hull 0)."""

    def __init__(self, data: bytes) -> None:
        self._planes = read_planes(data)
        nodes_entry = list_entry(data, LIST_NODES)
        self._nodes = [
            struct.unpack_from("<10i", data, nodes_entry.offset + index * NODE_SIZE)
            for index in range(nodes_entry.length // NODE_SIZE)
        ]
        leaves_entry = list_entry(data, LIST_LEAVES)
        self._leaf_contents = [
            struct.unpack_from("<i", data, leaves_entry.offset + index * LEAF_SIZE)[0]
            for index in range(leaves_entry.length // LEAF_SIZE)
        ]

    def contents(self, point: tuple[float, float, float] | list[float]) -> int:
        if not self._nodes:
            return CONTENTS_EMPTY
        node_index = 0
        while node_index >= 0:
            node = self._nodes[node_index]
            plane = self._planes[node[0]]
            side = plane.normal[0] * point[0] + plane.normal[1] * point[1] + plane.normal[2] * point[2] - plane.distance
            node_index = node[6] if side >= 0.0 else node[7]
        return self._leaf_contents[-node_index - 1]

    def is_solid(self, point: tuple[float, float, float] | list[float]) -> bool:
        return self.contents(point) == CONTENTS_SOLID


def read_vertices(data: bytes) -> list[tuple[float, float, float]]:
    entry = list_entry(data, LIST_VERTICES)
    return [struct.unpack_from("<3f", data, entry.offset + index * VERTEX_SIZE) for index in range(entry.length // VERTEX_SIZE)]


def read_edges(data: bytes) -> list[tuple[int, int]]:
    entry = list_entry(data, LIST_EDGES)
    count = entry.length // EDGE_SIZE
    values = struct.unpack_from(f"<{count * 2}I", data, entry.offset) if count else ()
    return [(values[index], values[index + 1]) for index in range(0, len(values), 2)]


def read_surfedges(data: bytes) -> list[int]:
    entry = list_entry(data, LIST_SURFEDGES)
    count = entry.length // SURFEDGE_SIZE
    return list(struct.unpack_from(f"<{count}i", data, entry.offset)) if count else []


def read_texinfos(data: bytes) -> list[TexInfo]:
    entry = list_entry(data, LIST_TEXINFO)
    texinfos: list[TexInfo] = []
    for index in range(entry.length // TEXINFO_SIZE):
        offset = entry.offset + index * TEXINFO_SIZE
        values = struct.unpack_from("<16f", data, offset)
        ints = struct.unpack_from("<16i", data, offset)
        texinfos.append(
            TexInfo(
                s_vector=values[0:4],
                t_vector=values[4:8],
                texture_index=ints[8],
                flags=ints[9],
            )
        )
    return texinfos


def read_faces(data: bytes) -> list[Face]:
    entry = list_entry(data, LIST_FACES)
    faces: list[Face] = []
    for index in range(entry.length // FACE_SIZE):
        unknown_0, side, first_edge, edge_count, texinfo, s0, s1, s2, s3, light_offset, plane, unknown_22 = struct.unpack_from(
            "<HHIHH4BIHH", data, entry.offset + index * FACE_SIZE
        )
        faces.append(
            Face(
                unknown_0=unknown_0,
                side=side,
                first_edge=first_edge,
                edge_count=edge_count,
                texinfo_index=texinfo,
                styles=(s0, s1, s2, s3),
                light_offset=light_offset,
                plane_index=plane,
                unknown_22=unknown_22,
            )
        )
    return faces


def face_edge_vertices(face: Face, edges: list[tuple[int, int]], surfedges: list[int]) -> list[int]:
    """Return the face winding as vertex indices (Quake surfedge convention)."""
    vertices: list[int] = []
    for ref in surfedges[face.first_edge : face.first_edge + face.edge_count]:
        edge = edges[abs(ref)]
        vertex = edge[0] if ref >= 0 else edge[1]
        if not vertices or vertices[-1] != vertex:
            vertices.append(vertex)
    if len(vertices) > 1 and vertices[0] == vertices[-1]:
        vertices.pop()
    return vertices


def read_texture_records(data: bytes, max_count: int | None = None) -> list[TextureRecord]:
    entry = list_entry(data, LIST_TEXTURES)
    if entry.length == 0:
        return []
    texture_count = struct.unpack_from("<I", data, entry.offset)[0]
    if texture_count <= 0 or (max_count is not None and texture_count > max_count):
        raise ValueError(f"unexpected WMB texture count: {texture_count}")
    table_values = struct.unpack_from(f"<{texture_count}I", data, entry.offset + 4)
    records: list[TextureRecord] = []
    for relative_offset in table_values:
        if relative_offset <= 0 or relative_offset >= entry.length:
            raise ValueError(f"invalid WMB texture offset: {relative_offset}")
        offset = entry.offset + relative_offset
        name = read_c_string(data[offset : offset + 16])
        width, height, format_hint = struct.unpack_from("<3I", data, offset + 16)
        if width <= 0 or height <= 0:
            raise ValueError(f"invalid WMB texture dimensions for {name!r}: {width}x{height}")
        records.append(TextureRecord(name=name, width=width, height=height, format_hint=format_hint, offset=offset))
    return records


def texture_payload(data: bytes, record: TextureRecord) -> bytes:
    payload = data[record.pixel_offset : record.pixel_offset + record.payload_size]
    if len(payload) != record.payload_size:
        raise ValueError(f"truncated WMB texture payload: {record.name}")
    return payload


def texture_payload_hash(data: bytes, record: TextureRecord) -> str:
    return hashlib.sha256(texture_payload(data, record)).hexdigest()


def rgb565_to_rgba(pixel: int) -> tuple[int, int, int, int]:
    red = ((pixel >> 11) & 0x1F) * 255 // 31
    green = ((pixel >> 5) & 0x3F) * 255 // 63
    blue = (pixel & 0x1F) * 255 // 31
    return red, green, blue, 255


_RGB565_RGBA_TABLE: list[bytes] | None = None


def _rgb565_table() -> list[bytes]:
    global _RGB565_RGBA_TABLE
    if _RGB565_RGBA_TABLE is None:
        _RGB565_RGBA_TABLE = [bytes(rgb565_to_rgba(value)) for value in range(65536)]
    return _RGB565_RGBA_TABLE


def rgb565_payload_to_rgba_bytes(payload: bytes) -> bytes:
    table = _rgb565_table()
    pixels = struct.unpack(f"<{len(payload) // 2}H", payload)
    return b"".join(table[value] for value in pixels)


def texture_image(data: bytes, record: TextureRecord) -> Image.Image:
    rgba = rgb565_payload_to_rgba_bytes(texture_payload(data, record))
    return Image.frombytes("RGBA", (record.width, record.height), rgba)


def _read_floats(data: bytes, offset: int, count: int) -> list[float]:
    return list(struct.unpack_from(f"<{count}f", data, offset))


def read_objects(data: bytes) -> list[dict[str, Any]]:
    """Decode the WMB4 objects list (entities, lights, sun, positions)."""
    entry = list_entry(data, LIST_OBJECTS)
    if entry.length < 4:
        return []
    count = struct.unpack_from("<I", data, entry.offset)[0]
    relative_offsets = list(struct.unpack_from(f"<{count}I", data, entry.offset + 4)) if count else []
    ends = relative_offsets[1:] + [entry.length]
    objects: list[dict[str, Any]] = []
    for index, (relative_offset, relative_end) in enumerate(zip(relative_offsets, ends)):
        offset = entry.offset + relative_offset
        size = relative_end - relative_offset
        object_type = struct.unpack_from("<I", data, offset)[0]
        record: dict[str, Any] = {"index": index, "type": object_type, "size": size}
        if object_type == OBJECT_TYPE_ENTITY and size >= 0x88:
            record.update(
                {
                    "position": _read_floats(data, offset + 0x04, 3),
                    "angles": _read_floats(data, offset + 0x10, 3),
                    "scale": _read_floats(data, offset + 0x1C, 3),
                    "name": read_c_string(data[offset + 0x28 : offset + 0x3C]),
                    "file": read_c_string(data[offset + 0x3C : offset + 0x49]),
                    "action": read_c_string(data[offset + 0x49 : offset + 0x60]),
                    "skills": _read_floats(data, offset + 0x60, ENTITY_SKILL_COUNT),
                    "flags": struct.unpack_from("<I", data, offset + 0x80)[0],
                    "extra_0x84": struct.unpack_from("<f", data, offset + 0x84)[0],
                }
            )
        elif object_type == OBJECT_TYPE_LIGHT and size >= 0x20:
            record.update(
                {
                    "position": _read_floats(data, offset + 0x04, 3),
                    "color_percent": _read_floats(data, offset + 0x10, 3),
                    "range": struct.unpack_from("<f", data, offset + 0x1C)[0],
                }
            )
        elif object_type == OBJECT_TYPE_SUN and size >= 0x18:
            record.update({"pan": struct.unpack_from("<f", data, offset + 0x10)[0], "tilt": struct.unpack_from("<f", data, offset + 0x14)[0]})
        elif object_type == OBJECT_TYPE_POSITION and size >= 0x38:
            record.update(
                {
                    "position": _read_floats(data, offset + 0x04, 3),
                    "angles": _read_floats(data, offset + 0x10, 3),
                    "name": read_c_string(data[offset + 0x24 : offset + 0x38]),
                }
            )
        else:
            record["raw_hex"] = data[offset : offset + size].hex()
        objects.append(record)
    return objects


def texinfo_st(point: tuple[float, float, float], texinfo: TexInfo) -> tuple[float, float]:
    s = point[0] * texinfo.s_vector[0] + point[1] * texinfo.s_vector[1] + point[2] * texinfo.s_vector[2] + texinfo.s_vector[3]
    t = point[0] * texinfo.t_vector[0] + point[1] * texinfo.t_vector[1] + point[2] * texinfo.t_vector[2] + texinfo.t_vector[3]
    return s, t


def face_lightmap_extent(points: list[tuple[float, float, float]], texinfo: TexInfo) -> tuple[int, int, int, int]:
    """Return (min_s_block, min_t_block, width, height) of a face lightmap in luxels."""
    st_values = [texinfo_st(point, texinfo) for point in points]
    min_s = math.floor(min(value[0] for value in st_values) / LIGHTMAP_BLOCK_SIZE)
    max_s = math.ceil(max(value[0] for value in st_values) / LIGHTMAP_BLOCK_SIZE)
    min_t = math.floor(min(value[1] for value in st_values) / LIGHTMAP_BLOCK_SIZE)
    max_t = math.ceil(max(value[1] for value in st_values) / LIGHTMAP_BLOCK_SIZE)
    return min_s, min_t, max_s - min_s + 1, max_t - min_t + 1
