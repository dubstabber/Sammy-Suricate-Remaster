extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAMERA_SCRIPT := preload("res://src/camera/third_person_camera.gd")
const DEBUG_OVERLAY_SCENE := preload("res://scenes/ui/debug_overlay.tscn")
const WMB_MANIFEST_SCRIPT := preload("res://src/levels/wmb_manifest.gd")
const WMB_MANIFEST_PATH := "res://assets/metadata/wmb_manifest.json"

var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
    _build_environment()
    _spawn_player()
    _spawn_camera()
    _spawn_props()
    _spawn_debug_overlay()
    _load_level_manifest()
    _start_music()


func _build_environment() -> void:
    var floor_body := StaticBody3D.new()
    floor_body.name = "PrototypeFloor"
    add_child(floor_body)

    var floor_mesh := MeshInstance3D.new()
    floor_mesh.name = "FloorMesh"
    var plane := PlaneMesh.new()
    plane.size = Vector2(24.0, 24.0)
    floor_mesh.mesh = plane
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.22, 0.32, 0.26)
    material.roughness = 0.85
    floor_mesh.material_override = material
    floor_body.add_child(floor_mesh)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(24.0, 1.0, 24.0)
    collision.shape = shape
    collision.position.y = -0.5
    floor_body.add_child(collision)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.light_energy = 2.3
    sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
    add_child(sun)

    var fill := OmniLight3D.new()
    fill.name = "FillLight"
    fill.position = Vector3(0.0, 5.0, 2.0)
    fill.light_energy = 1.5
    fill.omni_range = 18.0
    add_child(fill)


func _spawn_player() -> void:
    player = PLAYER_SCENE.instantiate()
    player.name = "Player"
    player.position = Vector3.ZERO
    add_child(player)


func _spawn_camera() -> void:
    camera = Camera3D.new()
    camera.name = "PrototypeCamera"
    camera.set_script(CAMERA_SCRIPT)
    add_child(camera)
    camera.target_path = camera.get_path_to(player)
    camera.reset_to_target()


func _spawn_props() -> void:
    _spawn_asset_prop("model.cactus1", Vector3(-4.0, 0.0, -2.0))
    _spawn_asset_prop("model.boost", Vector3(3.5, 0.0, -1.5))
    _spawn_asset_prop("model.rasta.animated", Vector3(-2.0, 0.0, -4.5))
    _spawn_asset_prop("model.punk.animated", Vector3(2.0, 0.0, -4.5))
    _spawn_asset_prop("model.sky3", Vector3(0.0, -0.2, 0.0))


func _spawn_asset_prop(asset_id: String, position: Vector3) -> void:
    var assets := get_node_or_null("/root/Assets")
    if assets == null:
        return
    var packed_scene: PackedScene = assets.load_asset(asset_id)
    if packed_scene == null:
        return

    var instance := packed_scene.instantiate() as Node3D
    instance.name = asset_id.replace(".", "_")
    instance.position = position
    instance.scale = assets.get_model_scale(asset_id)
    instance.rotation_degrees = assets.get_model_rotation_degrees(asset_id)
    add_child(instance)


func _spawn_debug_overlay() -> void:
    var overlay := DEBUG_OVERLAY_SCENE.instantiate()
    overlay.name = "DebugOverlay"
    add_child(overlay)
    overlay.player_path = overlay.get_path_to(player)


func _load_level_manifest() -> void:
    var manifest = WMB_MANIFEST_SCRIPT.new()
    var err: Error = manifest.load_file(WMB_MANIFEST_PATH)
    if err != OK:
        push_warning("Unable to read WMB manifest: %s" % error_string(err))
        return
    set_meta("wmb_manifest_counts", manifest.get_counts())


func _start_music() -> void:
    if bool(ProjectSettings.get_setting("sammy/test/skip_music", false)):
        return
    if not bool(ProjectSettings.get_setting("sammy/runtime/autoplay_music", false)):
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null:
        audio.play_music("music.sammy01")
