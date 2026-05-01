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
    "model.platform.default": {
        "path": "res://assets/models/platforms/platfor2/platfor2.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor2.wmb",
        "kind": "model",
        "description": "Original inactive moving platform WMB"
    },
    "model.platform.active": {
        "path": "res://assets/models/platforms/platfor1/platfor1.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor1.wmb",
        "kind": "model",
        "description": "Original activated moving platform WMB"
    },
    "model.platform.yellow": {
        "path": "res://assets/models/platforms/platfyel/platfyel.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfyel.wmb",
        "kind": "model",
        "description": "Original yellow key moving platform WMB"
    },
    "model.platform.red": {
        "path": "res://assets/models/platforms/platfred/platfred.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfred.wmb",
        "kind": "model",
        "description": "Original red key moving platform WMB"
    },
    "model.platform.orange": {
        "path": "res://assets/models/platforms/platfora/platfora.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfora.wmb",
        "kind": "model",
        "description": "Original orange key moving platform WMB"
    },
    "model.platform.blue": {
        "path": "res://assets/models/platforms/platfblu/platfblu.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfblu.wmb",
        "kind": "model",
        "description": "Original blue key moving platform WMB"
    },
    "model.platform.magenta": {
        "path": "res://assets/models/platforms/platfmag/platfmag.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfmag.wmb",
        "kind": "model",
        "description": "Original magenta key moving platform WMB"
    },
    "model.platform.green": {
        "path": "res://assets/models/platforms/platgree/platgree.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platgree.wmb",
        "kind": "model",
        "description": "Original green key moving platform WMB"
    },
    "model.platform.column_alt": {
        "path": "res://assets/models/platforms/platfor3/platfor3.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/platfor3.wmb",
        "kind": "model",
        "description": "Original alternate inactive moving platform WMB"
    },
    "model.teleport.pad": {
        "path": "res://assets/models/teleports/teleport/teleport.gltf",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
        "kind": "model",
        "description": "Original teleport pad WMB"
    },
    "texture.teleport.tile": {
        "path": "res://assets/textures/teleports/tileteleport2.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
        "kind": "texture",
        "description": "Original teleport pad top texture decoded from teleport.wmb"
    },
    "texture.teleport.tile_side": {
        "path": "res://assets/textures/teleports/tileteleport2_b.png",
        "source": "extract-sammy-assets/extracted/godot/raw/levels/teleport.wmb",
        "kind": "texture",
        "description": "Original teleport pad side texture decoded from teleport.wmb"
    },
    "model.enemy_visibility_range": {
        "path": "res://assets/models/circl100/circl100_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/circl100_animated.gltf",
        "kind": "model",
        "description": "Original Eye of Truth enemy range circle model"
    },
    "model.eye_of_truth": {
        "path": "res://assets/models/Paneye/Paneye.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/Paneye/Paneye.gltf",
        "kind": "model",
        "description": "Original Eye of Truth pickup and panel model"
    },
    "texture.enemy_visibility_range.skin_1": {
        "path": "res://assets/models/circl100/skins/circl100_skin0.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin0.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle idle skin"
    },
    "texture.enemy_visibility_range.skin_2": {
        "path": "res://assets/models/circl100/skins/circl100_skin1.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin1.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle alert skin"
    },
    "texture.enemy_visibility_range.skin_3": {
        "path": "res://assets/models/circl100/skins/circl100_skin2.png",
        "source": "extract-sammy-assets/extracted/godot/models/circl100/skins/circl100_skin2.png",
        "kind": "texture",
        "description": "Original Eye of Truth range circle chase skin"
    },
    "texture.eye_truth.panel": {
        "path": "res://assets/models/Paneye/skins/Paneye_skin0.png",
        "source": "extract-sammy-assets/extracted/godot/textures/eyetruth.png",
        "kind": "texture",
        "description": "Original Eye of Truth pickup and panel texture"
    },
    "texture.particle.small_star_1a": {
        "path": "res://assets/textures/particles/tistar1a.png",
        "source": "extract-sammy-assets/extracted/godot/textures/tistar1a.png",
        "kind": "texture",
        "description": "Original SmallStar1A sprite used by particle_Boost1"
    },
    "texture.particle.teleport_star_1": {
        "path": "res://assets/textures/particles/StarHit1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit1.png",
        "kind": "texture",
        "description": "Original StarHit1 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_2": {
        "path": "res://assets/textures/particles/StarHit2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit2.png",
        "kind": "texture",
        "description": "Original StarHit2 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_3": {
        "path": "res://assets/textures/particles/StarHit3.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit3.png",
        "kind": "texture",
        "description": "Original StarHit3 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_4": {
        "path": "res://assets/textures/particles/StarHit4.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit4.png",
        "kind": "texture",
        "description": "Original StarHit4 sprite used by particle_Teleport"
    },
    "texture.particle.teleport_star_5": {
        "path": "res://assets/textures/particles/StarHit5.png",
        "source": "extract-sammy-assets/extracted/godot/textures/StarHit5.png",
        "kind": "texture",
        "description": "Original StarHit5 sprite used by particle_Teleport"
    },
    "texture.particle.eye_truth_1": {
        "path": "res://assets/textures/particles/peye1.png",
        "source": "extract-sammy-assets/extracted/godot/textures/peye1.png",
        "kind": "texture",
        "description": "Original particle_RangeLion1 / particle_TakeEyeTruth sprite"
    },
    "texture.particle.eye_truth_2": {
        "path": "res://assets/textures/particles/peye2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/peye2.png",
        "kind": "texture",
        "description": "Original particle_RangeLion2 / particle_TakeEyeTruth sprite"
    },
    "texture.diamond.default": {
        "path": "res://assets/textures/score/gemgr+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemgr+17.png",
        "kind": "texture",
        "description": "Original green score diamond sprite sheet used by InitBonus3"
    },
    "texture.score.plus50": {
        "path": "res://assets/textures/score/plus50+6.png",
        "source": "extract-sammy-assets/extracted/godot/textures/plus50+6.png",
        "kind": "texture",
        "description": "Original +50 flying score sprite sheet"
    },
    "texture.score.plus100": {
        "path": "res://assets/textures/score/plu100+2.png",
        "source": "extract-sammy-assets/extracted/godot/textures/plu100+2.png",
        "kind": "texture",
        "description": "Original +100 flying score sprite sheet"
    },
    "texture.key_diamond.red": {
        "path": "res://assets/textures/key_diamonds/gemre+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemre+17.png",
        "kind": "texture",
        "description": "Original red key-diamond sprite sheet"
    },
    "texture.key_diamond.yellow": {
        "path": "res://assets/textures/key_diamonds/gemye+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemye+17.png",
        "kind": "texture",
        "description": "Original yellow key-diamond sprite sheet"
    },
    "texture.key_diamond.orange": {
        "path": "res://assets/textures/key_diamonds/gemor+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemor+17.png",
        "kind": "texture",
        "description": "Original orange mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.blue": {
        "path": "res://assets/textures/key_diamonds/gembl+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gembl+17.png",
        "kind": "texture",
        "description": "Original blue key-diamond sprite sheet"
    },
    "texture.key_diamond.magenta": {
        "path": "res://assets/textures/key_diamonds/gemma+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemma+17.png",
        "kind": "texture",
        "description": "Original magenta mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.green": {
        "path": "res://assets/textures/key_diamonds/gemve+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemve+17.png",
        "kind": "texture",
        "description": "Original green mixed key-diamond sprite sheet"
    },
    "texture.key_diamond.multi": {
        "path": "res://assets/textures/key_diamonds/gemmu+17.png",
        "source": "extract-sammy-assets/extracted/godot/textures/gemmu+17.png",
        "kind": "texture",
        "description": "Original all-key/multi key-diamond sprite sheet"
    },
    "texture.ui.gem_panel_bar": {
        "path": "res://assets/textures/ui/hbargems.png",
        "source": "extract-sammy-assets/extracted/godot/textures/hbargems.png",
        "kind": "texture",
        "description": "Original key-diamond panel strip"
    },
    "texture.ui.gem_panel_background": {
        "path": "res://assets/textures/ui/fondgems.png",
        "source": "extract-sammy-assets/extracted/godot/textures/fondgems.png",
        "kind": "texture",
        "description": "Original key-diamond panel background"
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
    "sfx.colored_gem": {
        "path": "res://assets/audio/gemding2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/gemding2.wav",
        "kind": "audio",
        "description": "Original ColoredGem_son used by key-diamond pickups"
    },
    "sfx.diamond": {
        "path": "res://assets/audio/diam.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/diam.wav",
        "kind": "audio",
        "description": "Original Diam_son used by score diamond pickups"
    },
    "sfx.boost_pickup": {
        "path": "res://assets/audio/Chimes2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Chimes2.wav",
        "kind": "audio",
        "description": "Original speed boost pickup chime"
    },
    "sfx.eye_truth": {
        "path": "res://assets/audio/EyeTruth.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/EyeTruth.wav",
        "kind": "audio",
        "description": "Original EyeTruth_son pickup sound"
    },
    "sfx.quick_turn": {
        "path": "res://assets/audio/Blouit.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Blouit.wav",
        "kind": "audio",
        "description": "Original Blouit_son used by RetourneSammy quick turn"
    },
    "sfx.key_mix": {
        "path": "res://assets/audio/Gemmix.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/Gemmix.wav",
        "kind": "audio",
        "description": "Original GemMixing_son used when two key diamonds combine"
    },
    "sfx.key_mix_end": {
        "path": "res://assets/audio/EndGemmi.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/EndGemmi.wav",
        "kind": "audio",
        "description": "Original EndGemMixing_son used at the end of key mixing"
    },
    "sfx.door_open": {
        "path": "res://assets/audio/dooropen.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/dooropen.wav",
        "kind": "audio",
        "description": "Original DoorOpen_son"
    },
    "sfx.door_close": {
        "path": "res://assets/audio/doorclos.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/doorclos.wav",
        "kind": "audio",
        "description": "Original DoorClose_son"
    },
    "sfx.platform_activate": {
        "path": "res://assets/audio/platfor2.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/platfor2.wav",
        "kind": "audio",
        "description": "Original Platform1_son used when moving platforms activate"
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
    "sfx.error": {
        "path": "res://assets/audio/error1.wav",
        "source": "extract-sammy-assets/extracted/godot/audio/error1.wav",
        "kind": "audio",
        "description": "Original Error1_son used for rejected actions"
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
        "path": "res://assets/models/wasp1/wasp1_animated.gltf",
        "source": "extract-sammy-assets/extracted/godot/models/wasp1/wasp1_animated.gltf",
        "kind": "model",
        "description": "Original wasp projectile morph-target animation model",
        "rotation_degrees": ACKNEX_CHARACTER_FORWARD_ROTATION,
        "animation_library": "res://assets/animations/wasp1_clips.tres",
        "default_animation": "stand"
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
    },
    "metadata.platform_wmb_manifest": {
        "path": "res://assets/models/platforms/platform_wmb_manifest.json",
        "source": "extract-sammy-assets/extracted/godot/raw/levels",
        "kind": "metadata",
        "description": "Converted original moving platform WMB manifest"
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
    if skin_index <= 0:
        return ""
    return "res://assets/models/wasp1/skins/wasp1_skin%d.png" % (skin_index - 1)


func get_wasp_leg_skin_path(skin_index: int) -> String:
    if skin_index <= 0:
        return ""
    return "res://assets/models/wasp1/skins/legs/wasp1_skin%d_legs.png" % (skin_index - 1)


func load_wasp_skin_texture(skin_index: int) -> Texture2D:
    var texture_path := get_wasp_skin_path(skin_index)
    if texture_path.is_empty():
        return null
    if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path):
        return null
    return load(texture_path) as Texture2D


func load_wasp_leg_skin_texture(skin_index: int) -> Texture2D:
    var texture_path := get_wasp_leg_skin_path(skin_index)
    if texture_path.is_empty():
        return null
    if not ResourceLoader.exists(texture_path) and not FileAccess.file_exists(texture_path):
        return null
    return load(texture_path) as Texture2D


func load_enemy_visibility_range_skin_texture(skin_number: int) -> Texture2D:
    var clamped_skin := clampi(skin_number, 1, 3)
    return load_asset("texture.enemy_visibility_range.skin_%d" % clamped_skin) as Texture2D


func apply_wasp_skin(model_root: Node3D, skin_index: int) -> bool:
    if model_root == null:
        return false
    var texture := load_wasp_skin_texture(skin_index)
    if texture == null:
        return false
    var leg_texture := load_wasp_leg_skin_texture(skin_index)
    if leg_texture == null:
        leg_texture = texture
    _apply_wasp_textures_to_meshes(model_root, texture, leg_texture)
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


func _apply_texture_to_meshes(node: Node, texture: Texture2D, use_alpha: bool = false) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var base_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            var material := _build_textured_material(base_material, texture, use_alpha)
            mesh_instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_texture_to_meshes(child, texture, use_alpha)


func _apply_wasp_textures_to_meshes(node: Node, body_texture: Texture2D, leg_texture: Texture2D) -> void:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        var surface_count := mesh_instance.mesh.get_surface_count()
        for surface_index in range(surface_count):
            var base_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            # Surface 1 is the generated mirrored/lower-leg primitive split from wasp1.MDL triangles 79-95.
            var is_leg_surface := surface_count > 1 and surface_index > 0
            var texture := leg_texture if is_leg_surface else body_texture
            var material := _build_textured_material(base_material, texture, true)
            if is_leg_surface:
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mesh_instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_wasp_textures_to_meshes(child, body_texture, leg_texture)


func _build_textured_material(base_material: StandardMaterial3D, texture: Texture2D, use_alpha: bool) -> StandardMaterial3D:
    var material: StandardMaterial3D = null
    if base_material != null:
        material = base_material.duplicate() as StandardMaterial3D
    else:
        material = StandardMaterial3D.new()
    material.albedo_texture = texture
    if use_alpha:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        material.alpha_scissor_threshold = 0.5
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    return material


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
