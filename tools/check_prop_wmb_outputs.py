#!/usr/bin/env python3
"""Regression check: re-convert every prop WMB family and byte-compare outputs.

Each `assets/models/**/*_wmb_manifest.json` was produced by one run of
`tools/convert_gate_wmb_models.py` with family-specific roots. This script
re-runs the converter for every family into a temporary tree that mirrors the
repository layout (so relative image URIs stay identical) and compares the
generated `.gltf`, `.bin`, and texture `.png` files against the committed ones.
"""

from __future__ import annotations

import argparse
import filecmp
import json
import sys
import tempfile
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import convert_gate_wmb_models as prop_converter  # noqa: E402


def family_texture_root(repo_root: Path, model_root: Path, converted: list[dict[str, object]]) -> Path:
    for entry in converted:
        gltf_path = repo_root / str(entry["output"])
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        images = gltf.get("images", [])
        if images:
            return (gltf_path.parent / str(images[0]["uri"])).resolve().parent
    raise ValueError(f"no texture images found for family {model_root}")


def compare_file(expected: Path, actual: Path, mismatches: list[str]) -> None:
    if not actual.exists():
        mismatches.append(f"missing output: {actual}")
    elif not expected.exists():
        mismatches.append(f"missing committed file: {expected}")
    elif not filecmp.cmp(expected, actual, shallow=False):
        mismatches.append(f"differs: {expected}")


def check_family(repo_root: Path, manifest_path: Path, temp_root: Path) -> tuple[int, list[str]]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    converted: list[dict[str, object]] = list(manifest["converted"])
    model_root = manifest_path.parent.resolve()
    texture_root = family_texture_root(repo_root, model_root, converted)
    temp_model_root = temp_root / model_root.relative_to(repo_root)
    temp_texture_root = temp_root / texture_root.relative_to(repo_root)

    source_paths = [repo_root / str(entry["source"]) for entry in converted]
    source_dirs = {path.parent for path in source_paths}
    if len(source_dirs) != 1:
        raise ValueError(f"{manifest_path} mixes source directories: {sorted(source_dirs)}")
    source_dir = source_dirs.pop()
    source_names = [path.name for path in source_paths]
    colliding = prop_converter.find_colliding_texture_names(source_dir, source_names)

    mismatches: list[str] = []
    identical = 0
    for entry, source_path in zip(converted, source_paths):
        result = prop_converter.convert_wmb(source_path, temp_model_root, temp_texture_root, colliding)
        before = len(mismatches)
        expected_gltf = repo_root / str(entry["output"])
        actual_gltf = Path(str(result["output"]))
        compare_file(expected_gltf, actual_gltf, mismatches)
        compare_file(expected_gltf.with_suffix(".bin"), actual_gltf.with_suffix(".bin"), mismatches)
        for texture_file in result["texture_files"]:
            compare_file(texture_root / str(texture_file), temp_texture_root / str(texture_file), mismatches)
        for key, value in entry.items():
            if key in {"source", "output"}:
                continue
            if result.get(key) != value:
                mismatches.append(f"manifest field {key!r} differs for {source_path.name}: {value!r} -> {result.get(key)!r}")
        if len(mismatches) == before:
            identical += 1
    return identical, mismatches


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=TOOLS_DIR.parent)
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()

    manifests = sorted((repo_root / "assets/models").rglob("*_wmb_manifest.json"))
    total = 0
    identical = 0
    mismatches: list[str] = []
    with tempfile.TemporaryDirectory(prefix="sammy-prop-wmb-") as temp_dir:
        temp_root = Path(temp_dir)
        for manifest_path in manifests:
            family_total = len(json.loads(manifest_path.read_text(encoding="utf-8"))["converted"])
            family_identical, family_mismatches = check_family(repo_root, manifest_path, temp_root)
            total += family_total
            identical += family_identical
            mismatches.extend(family_mismatches)
            print(f"{manifest_path.relative_to(repo_root)}: {family_identical}/{family_total} identical")

    for mismatch in mismatches:
        print(f"  {mismatch}")
    print(f"prop WMB outputs: {identical}/{total} identical")
    return 0 if identical == total and not mismatches else 1


if __name__ == "__main__":
    raise SystemExit(main())
