extends Node

const AssetEntryScript := preload("res://src/resources/asset_entry.gd")

const ACKNEX_TO_GODOT_SCALE := 0.01

const CATALOG := {
    "model.sammy.static": {
        "path": "res://assets/models/suricat1/suricat1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1.gltf",
        "kind": "model",
        "description": "Sammy first-frame model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0)
    },
    "model.sammy.animated": {
        "path": "res://assets/models/suricat1/suricat1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1_animated.gltf",
        "kind": "model",
        "description": "Sammy morph-target animation preview model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0)
    },
    "model.rasta.animated": {
        "path": "res://assets/models/rasta/rasta_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/rasta/rasta_animated.gltf",
        "kind": "model",
        "description": "Rasta enemy morph-target animation preview model"
    },
    "model.punk.animated": {
        "path": "res://assets/models/Punk/Punk_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/Punk/Punk_animated.gltf",
        "kind": "model",
        "description": "Punk enemy morph-target animation preview model"
    },
    "model.sky3": {
        "path": "res://assets/models/sky3/sky3.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky3/sky3.gltf",
        "kind": "model",
        "description": "Original sky reference model"
    },
    "model.cactus1": {
        "path": "res://assets/models/cactus1/cactus1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/cactus1/cactus1.gltf",
        "kind": "model",
        "description": "Prototype level prop"
    },
    "model.boost": {
        "path": "res://assets/models/boost/boost_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/boost/boost_animated.gltf",
        "kind": "model",
        "description": "Prototype collectible prop"
    },
    "music.sammy01": {
        "path": "res://assets/audio/sammy01.ogg",
        "source": "extract-sammy-assets/extracted/godot/audio/sammy01.ogg",
        "kind": "music",
        "description": "Rendered original MIDI track"
    },
    "sfx.collect": {
        "path": "res://assets/audio/gemding2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/gemding2.wav",
        "kind": "audio",
        "description": "Gem pickup sound"
    },
    "sfx.hit": {
        "path": "res://assets/audio/Hit1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Hit1.wav",
        "kind": "audio",
        "description": "Impact sound"
    },
    "sfx.wasp": {
        "path": "res://assets/audio/wasp.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/wasp.wav",
        "kind": "audio",
        "description": "Wasp sound"
    },
    "sfx.player": {
        "path": "res://assets/audio/haway.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/haway.wav",
        "kind": "audio",
        "description": "Player vocalization sample"
    },
    "metadata.wmb_manifest": {
        "path": "res://assets/metadata/wmb_manifest.json",
        "source": "extract-sammy-assets/extracted/godot/levels/wmb_manifest.json",
        "kind": "metadata",
        "description": "WMB dependency manifest copied from extraction output"
    }
}

var entries: Dictionary = {}


func _ready() -> void:
    rebuild()


func rebuild() -> void:
    entries.clear()
    for entry_id: String in CATALOG.keys():
        var raw: Dictionary = CATALOG[entry_id]
        entries[entry_id] = AssetEntryScript.new(
                entry_id,
                raw.get("path", ""),
                raw.get("source", ""),
                raw.get("kind", ""),
                raw.get("description", ""),
                raw.get("acknex_entity_scale", Vector3.ONE),
                raw.get("rotation_degrees", Vector3.ZERO)
        )


func has_asset(entry_id: String) -> bool:
    _ensure_built()
    return entries.has(entry_id)


func get_entry(entry_id: String) -> Resource:
    _ensure_built()
    return entries.get(entry_id)


func get_asset_path(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.path


func load_asset(entry_id: String) -> Resource:
    var resource_path := get_asset_path(entry_id)
    if resource_path.is_empty():
        push_warning("Unknown asset id: %s" % entry_id)
        return null
    return load(resource_path)


func get_model_scale(entry_id: String) -> Vector3:
    var entry := get_entry(entry_id)
    if entry == null:
        return Vector3.ONE * ACKNEX_TO_GODOT_SCALE
    return entry.acknex_entity_scale * ACKNEX_TO_GODOT_SCALE


func get_model_rotation_degrees(entry_id: String) -> Vector3:
    var entry := get_entry(entry_id)
    if entry == null:
        return Vector3.ZERO
    return entry.rotation_degrees


func verify_required_assets() -> Array[String]:
    _ensure_built()
    var missing: Array[String] = []
    for entry_id: String in entries.keys():
        var entry: Resource = entries[entry_id]
        if not ResourceLoader.exists(entry.path) and not FileAccess.file_exists(entry.path):
            missing.append("%s -> %s" % [entry_id, entry.path])
    return missing


func all_entries() -> Array[Resource]:
    _ensure_built()
    var result: Array[Resource] = []
    for entry_id: String in entries.keys():
        result.append(entries[entry_id])
    return result


func _ensure_built() -> void:
    if entries.is_empty():
        rebuild()
