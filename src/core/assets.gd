extends Node

const AssetEntryScript := preload("res://src/resources/asset_entry.gd")

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_CHARACTER_FORWARD_ROTATION := Vector3(0.0, 90.0, 0.0)

const CATALOG := {
    "model.sammy.static": {
        "path": "res://assets/models/suricat1/suricat1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1.gltf",
        "kind": "model",
        "description": "Sammy first-frame model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0),
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true
    },
    "model.sammy.animated": {
        "path": "res://assets/models/suricat1/suricat1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/suricat1/suricat1_animated.gltf",
        "kind": "model",
        "description": "Sammy morph-target animation preview model",
        "acknex_entity_scale": Vector3(8.0, 8.0, 8.0),
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/suricat1_clips.tres",
        "default_animation": "stand"
    },
    "model.rasta.animated": {
        "path": "res://assets/models/rasta/rasta_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/rasta/rasta_animated.gltf",
        "kind": "model",
        "description": "Rasta enemy morph-target animation preview model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/rasta_clips.tres",
        "default_animation": "stand"
    },
    "model.punk.animated": {
        "path": "res://assets/models/Punk/Punk_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/Punk/Punk_animated.gltf",
        "kind": "model",
        "description": "Punk enemy morph-target animation preview model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "ground_to_floor": true,
        "animation_library": "res://assets/animations/punk_clips.tres",
        "default_animation": "stand"
    },
    "model.sky3": {
        "path": "res://assets/models/sky3/sky3.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/sky3/sky3.gltf",
        "kind": "model",
        "description": "Original sky reference model"
    },
    "model.cactus1": {
        "path": "res://assets/models/cactus1/cactus1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/cactus1/cactus1_animated.gltf",
        "kind": "model",
        "description": "Prototype level prop",
        "animation_library": "res://assets/animations/cactus1_clips.tres",
        "default_animation": "stand"
    },
    "model.boost": {
        "path": "res://assets/models/boost/boost_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/boost/boost_animated.gltf",
        "kind": "model",
        "description": "Prototype collectible prop",
        "animation_library": "res://assets/animations/boost_clips.tres",
        "default_animation": "stand"
    },
    "texture.particle.small_star_1a": {
        "path": "res://assets/textures/particles/tistar1a.png",
        "source": "extract-sammy-assets/extracted/godot/textures/tistar1a.png",
        "kind": "texture",
        "description": "Original SmallStar1A sprite used by particle_Boost1"
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
    "sfx.boost_pickup": {
        "path": "res://assets/audio/Chimes2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Chimes2.wav",
        "kind": "audio",
        "description": "Original speed boost pickup chime"
    },
    "sfx.quick_turn": {
        "path": "res://assets/audio/Blouit.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Blouit.wav",
        "kind": "audio",
        "description": "Original Blouit_son used by RetourneSammy quick turn"
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
    "sfx.takewasp": {
        "path": "res://assets/audio/takewasp.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/takewasp.wav",
        "kind": "audio",
        "description": "Original TakeWasp_son wasp pickup chime"
    },
    "sfx.wasp_kaput": {
        "path": "res://assets/audio/WaspKapu.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/WaspKapu.wav",
        "kind": "audio",
        "description": "Original WaspKaputt_son wasp impact sound"
    },
    "model.wasp1": {
        "path": "res://assets/models/wasp1/wasp1.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/wasp1/wasp1.gltf",
        "kind": "model",
        "description": "Original wasp projectile model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION
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
                raw.get("rotation_degrees", Vector3.ZERO),
                bool(raw.get("ground_to_floor", false)),
                raw.get("animation_library", ""),
                raw.get("default_animation", "")
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
    var asset_resource_path := get_asset_path(entry_id)
    if asset_resource_path.is_empty():
        push_warning("Unknown asset id: %s" % entry_id)
        return null
    return load(asset_resource_path)


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


func should_ground_model(entry_id: String) -> bool:
    var entry := get_entry(entry_id)
    if entry == null:
        return false
    return bool(entry.ground_to_floor)


func get_model_animation_library_path(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.animation_library_path


func get_model_default_animation(entry_id: String) -> String:
    var entry := get_entry(entry_id)
    if entry == null:
        return ""
    return entry.default_animation


func get_wasp_skin_path(skin_index: int) -> String:
    if skin_index < 0:
        return ""
    return "res://assets/models/wasp1/skins/wasp1_skin%d.png" % skin_index


func load_wasp_skin_texture(skin_index: int) -> Texture2D:
    var texture_path := get_wasp_skin_path(skin_index)
    if texture_path.is_empty():
        return null
    if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path):
        return null
    return load(texture_path) as Texture2D


func apply_wasp_skin(model_root: Node3D, skin_index: int) -> bool:
    if model_root == null:
        return false
    var texture := load_wasp_skin_texture(skin_index)
    if texture == null:
        return false
    _apply_texture_to_meshes(model_root, texture)
    return true


func align_model_instance_to_ground(model_root: Node3D, ground_y: float = 0.0) -> void:
    var bounds := get_model_global_bounds(model_root)
    if bounds.size == Vector3.ZERO:
        return

    var lift := ground_y - bounds.position.y
    if is_zero_approx(lift):
        return
    model_root.global_position.y += lift


func get_model_global_bounds(model_root: Node3D) -> AABB:
    var state := {
        "has_bounds": false,
        "bounds": AABB()
    }
    _accumulate_mesh_bounds(model_root, state)
    return state["bounds"] if state["has_bounds"] else AABB()


func verify_required_assets() -> Array[String]:
    _ensure_built()
    var missing: Array[String] = []
    for entry_id: String in entries.keys():
        var entry: Resource = entries[entry_id]
        if not ResourceLoader.exists(entry.path) and not FileAccess.file_exists(entry.path):
            missing.append("%s -> %s" % [entry_id, entry.path])
        if not entry.animation_library_path.is_empty():
            if not ResourceLoader.exists(entry.animation_library_path) and not FileAccess.file_exists(entry.animation_library_path):
                missing.append("%s animation -> %s" % [entry_id, entry.animation_library_path])
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


func _accumulate_mesh_bounds(node: Node, state: Dictionary) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null:
        var mesh_bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
        if state["has_bounds"]:
            state["bounds"] = (state["bounds"] as AABB).merge(mesh_bounds)
        else:
            state["bounds"] = mesh_bounds
            state["has_bounds"] = true

    for child in node.get_children():
        _accumulate_mesh_bounds(child, state)


func _apply_texture_to_meshes(node: Node, texture: Texture2D) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var base_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            var material: StandardMaterial3D = null
            if base_material != null:
                material = base_material.duplicate() as StandardMaterial3D
            else:
                material = StandardMaterial3D.new()
            material.albedo_texture = texture
            mesh_instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_texture_to_meshes(child, texture)


func _transform_aabb(transform: Transform3D, bounds: AABB) -> AABB:
    var points: Array[Vector3] = [
        bounds.position,
        bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
        bounds.position + Vector3(0.0, bounds.size.y, 0.0),
        bounds.position + Vector3(0.0, 0.0, bounds.size.z),
        bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
        bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
        bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
        bounds.position + bounds.size
    ]

    var transformed := AABB(transform * points[0], Vector3.ZERO)
    for index in range(1, points.size()):
        transformed = transformed.expand(transform * points[index])
    return transformed
