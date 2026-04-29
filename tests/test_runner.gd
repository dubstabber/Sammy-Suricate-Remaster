extends SceneTree

const ASSETS_SCRIPT_PATH := "res://src/core/assets.gd"
const WMB_MANIFEST_SCRIPT_PATH := "res://src/levels/wmb_manifest.gd"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const EDITOR_PREVIEW_SCRIPT_PATH := "res://src/editor/sammy_editor_model_preview.gd"
const CAMERA_SCRIPT_PATH := "res://src/camera/third_person_camera.gd"
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"
const WASP_PICKUP_SCENE_PATH := "res://scenes/pickups/wasp_pickup.tscn"
const BOOST_PICKUP_SCENE_PATH := "res://scenes/pickups/boost_pickup.tscn"
const WASP_PROJECTILE_SCENE_PATH := "res://scenes/weapons/wasp_projectile.tscn"
const WASP_TYPE_PATHS := [
    "",
    "res://assets/wasps/type_1.tres",
    "res://assets/wasps/type_2.tres",
    "res://assets/wasps/type_3.tres",
    "res://assets/wasps/type_4.tres",
    "res://assets/wasps/type_5.tres",
    "res://assets/wasps/type_6.tres",
    "res://assets/wasps/type_7.tres"
]
const WASP_TYPE_2_PATH := "res://assets/wasps/type_2.tres"
const WASP_TYPE_3_PATH := "res://assets/wasps/type_3.tres"
const WASP_TYPE_5_PATH := "res://assets/wasps/type_5.tres"
const WASP_INVENTORY_SCRIPT_PATH := "res://src/weapons/wasp_inventory.gd"
const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4
const PROJECTILE_LAYER := 8
const WORLD_AND_CHARACTER_MASK := 3

var _failures: Array[String] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var assets := _ensure_assets_service()
    await process_frame

    _test_input_actions()
    _test_display_settings()
    _test_collision_layer_names()
    _test_asset_catalog(assets)
    await _test_editor_model_previews(assets)
    _test_animation_libraries()
    _test_model_skin_alpha()
    _test_wmb_manifest()
    _test_wasp_resources(assets)
    _test_wasp_inventory()
    await _test_wasp_projectile_damages_enemy()
    await _test_wasp_projectile_behaviors()
    await _test_player_scene()
    ProjectSettings.set_setting("sammy/test/skip_music", true)
    await _test_main_scene()
    await _test_prototype_world()
    ProjectSettings.set_setting("sammy/test/skip_music", false)

    if _failures.is_empty():
        print("All scaffold smoke tests passed.")
        quit(0)
    else:
        for failure in _failures:
            push_error(failure)
        quit(1)


func _ensure_assets_service() -> Node:
    var existing := root.get_node_or_null("Assets")
    if existing != null:
        return existing

    var assets_script: GDScript = load(ASSETS_SCRIPT_PATH)
    var assets: Node = assets_script.new()
    assets.name = "Assets"
    root.add_child(assets)
    return assets


func _test_input_actions() -> void:
    for action in ["move_forward", "move_back", "turn_left", "turn_right", "jump", "fire", "boost", "quick_turn", "camera_change", "restart_level", "menu_cancel", "menu_confirm", "menu_accept"]:
        _expect(InputMap.has_action(action), "Missing input action: %s" % action)

    for removed_action in ["move_left", "move_right", "interact", "camera_reset", "debug_toggle"]:
        _expect(not InputMap.has_action(removed_action), "Obsolete placeholder input action should be removed: %s" % removed_action)

    _expect(_action_has_key("move_forward", KEY_NONE, KEY_UP), "Move forward should use the Up arrow.")
    _expect(_action_has_key("move_back", KEY_NONE, KEY_DOWN), "Move back should use the Down arrow.")
    _expect(_action_has_key("turn_left", KEY_NONE, KEY_LEFT), "Turn left should use the Left arrow.")
    _expect(_action_has_key("turn_right", KEY_NONE, KEY_RIGHT), "Turn right should use the Right arrow.")
    _expect(_action_has_key("jump", KEY_NONE, KEY_CTRL), "Jump should use Ctrl.")
    _expect(_action_has_key("fire", KEY_SPACE, KEY_NONE), "Fire should use Space.")
    _expect(_action_has_key("boost", KEY_NONE, KEY_SHIFT), "Boost should use Shift.")
    _expect(_action_has_key("quick_turn", KEY_NONE, KEY_ALT), "Quick turn should use Alt.")
    _expect(_action_has_key("camera_change", KEY_C, KEY_NONE), "Camera change should use C.")
    _expect(_action_has_key("restart_level", KEY_R, KEY_NONE), "Restart should use R.")
    _expect(_action_has_key("menu_cancel", KEY_NONE, KEY_ESCAPE), "Menu cancel should use Esc.")
    _expect(_action_has_key("menu_confirm", KEY_NONE, KEY_ENTER), "Menu confirm should use Enter.")

    _expect(_action_has_joy_button("move_forward", JOY_BUTTON_DPAD_UP), "Move forward should support D-pad up.")
    _expect(_action_has_joy_button("move_back", JOY_BUTTON_DPAD_DOWN), "Move back should support D-pad down.")
    _expect(_action_has_joy_button("turn_left", JOY_BUTTON_DPAD_LEFT), "Turn left should support D-pad left.")
    _expect(_action_has_joy_button("turn_right", JOY_BUTTON_DPAD_RIGHT), "Turn right should support D-pad right.")
    _expect(_action_has_joy_motion("move_forward", JOY_AXIS_LEFT_Y, -1.0), "Move forward should support left-stick up.")
    _expect(_action_has_joy_motion("move_back", JOY_AXIS_LEFT_Y, 1.0), "Move back should support left-stick down.")
    _expect(_action_has_joy_motion("turn_left", JOY_AXIS_LEFT_X, -1.0), "Turn left should support left-stick left.")
    _expect(_action_has_joy_motion("turn_right", JOY_AXIS_LEFT_X, 1.0), "Turn right should support left-stick right.")
    _expect(_action_has_joy_button("jump", JOY_BUTTON_A), "Jump should support joy button 1.")
    _expect(_action_has_joy_button("fire", JOY_BUTTON_B), "Fire should support joy button 2.")
    _expect(_action_has_joy_button("boost", JOY_BUTTON_X), "Boost should support joy button 3.")
    _expect(_action_has_joy_button("quick_turn", JOY_BUTTON_Y), "Quick turn should support joy button 4.")
    _expect(_action_has_mouse_button("menu_accept", MOUSE_BUTTON_LEFT), "Menu accept should support left mouse click.")


func _test_display_settings() -> void:
    _expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280, "Game viewport width should be 1280.")
    _expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 960, "Game viewport height should be 960.")
    _expect(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport", "Game viewport should scale to the window.")
    _expect(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep", "Game viewport should preserve its aspect ratio.")


func _test_collision_layer_names() -> void:
    _expect(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_1")) == "world", "3D physics layer 1 should be named world.")
    _expect(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_2")) == "character", "3D physics layer 2 should be named character.")
    _expect(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_3")) == "pickup_sensor", "3D physics layer 3 should be named pickup_sensor.")
    _expect(String(ProjectSettings.get_setting("layer_names/3d_physics/layer_4")) == "projectile", "3D physics layer 4 should be named projectile.")


func _test_asset_catalog(assets: Node) -> void:
    _expect(assets.has_asset("model.sammy.animated"), "Asset catalog is missing Sammy animated model.")
    _expect(assets.has_asset("metadata.wmb_manifest"), "Asset catalog is missing WMB manifest metadata.")
    var missing: Array[String] = assets.verify_required_assets()
    _expect(missing.is_empty(), "Missing catalog files: %s" % [", ".join(missing)])
    _expect(assets.load_asset("model.sammy.animated") != null, "Unable to load Sammy animated model resource.")
    _expect(assets.load_asset("model.rasta.animated") != null, "Unable to load copied rasta model resource.")
    _expect(assets.load_asset("model.punk.animated") != null, "Unable to load copied punk model resource.")
    _expect(assets.load_asset("model.boost") != null, "Unable to load copied boost model resource.")
    _expect(assets.load_asset("model.cactus1") != null, "Unable to load copied cactus model resource.")
    _expect(assets.has_asset("texture.particle.small_star_1a"), "Asset catalog is missing original boost particle sprite.")
    _expect(assets.load_asset("texture.particle.small_star_1a") != null, "Unable to load original boost particle sprite.")
    _expect(assets.get_model_scale("model.sammy.animated").is_equal_approx(Vector3(0.08, 0.08, 0.08)), "Sammy model scale should include original WDL scale 8.")
    _expect(assets.get_model_scale("model.rasta.animated").is_equal_approx(Vector3(0.01, 0.01, 0.01)), "Rasta model should use default Acknex entity scale.")
    _expect(assets.get_model_rotation_degrees("model.sammy.animated").is_equal_approx(Vector3(0.0, 90.0, 0.0)), "Sammy model should rotate Acknex +X forward to Godot -Z forward.")
    _expect(assets.get_model_rotation_degrees("model.rasta.animated").is_equal_approx(Vector3(0.0, 90.0, 0.0)), "Rasta model should use the Acknex character forward correction.")
    _expect(assets.get_model_rotation_degrees("model.punk.animated").is_equal_approx(Vector3(0.0, 90.0, 0.0)), "Punk model should use the Acknex character forward correction.")
    _expect(assets.get_model_rotation_degrees("model.cactus1").is_equal_approx(Vector3.ZERO), "Static props should not inherit the character forward correction.")
    _expect(assets.should_ground_model("model.sammy.animated"), "Sammy model should be grounded to the floor.")
    _expect(assets.should_ground_model("model.rasta.animated"), "Rasta model should be grounded to the floor.")
    _expect(assets.should_ground_model("model.punk.animated"), "Punk model should be grounded to the floor.")
    _expect(not assets.should_ground_model("model.cactus1"), "Static props should not use character grounding.")
    _expect(assets.get_model_animation_library_path("model.sammy.animated") == "res://assets/animations/suricat1_clips.tres", "Sammy should use the generated animation library.")
    _expect(assets.get_model_default_animation("model.rasta.animated") == "stand", "Rasta should expose a default stand animation.")
    _expect(assets.has_asset("music.sammy01"), "Asset catalog is missing copied music resource.")
    _expect(assets.load_asset("sfx.collect") != null, "Unable to load copied sound-effect resource.")
    _expect(assets.load_asset("sfx.boost_pickup") != null, "Unable to load original boost pickup sound.")
    _expect(assets.load_asset("sfx.quick_turn") != null, "Unable to load original Blouit quick-turn sound.")
    _expect(assets.has_asset("model.wasp1"), "Asset catalog is missing wasp projectile model.")
    _expect(assets.load_asset("model.wasp1") != null, "Unable to load wasp projectile model.")
    _expect(assets.get_asset_path("model.wasp1") == "res://assets/models/wasp1/wasp1_animated.gltf", "Wasp runtime model should use the animated GLTF.")
    _expect(assets.get_model_animation_library_path("model.wasp1") == "res://assets/animations/wasp1_clips.tres", "Wasp should use the generated animation library.")
    _expect(assets.get_model_default_animation("model.wasp1") == "stand", "Wasp should expose the original stand animation as default.")
    _expect(assets.has_asset("sfx.error"), "Asset catalog is missing original rejected-action sound.")
    _expect(assets.load_asset("sfx.error") != null, "Unable to load original rejected-action sound.")
    _expect(assets.has_asset("sfx.takewasp"), "Asset catalog is missing original wasp pickup chime.")
    _expect(assets.load_asset("sfx.takewasp") != null, "Unable to load original wasp pickup chime.")
    _expect(assets.has_asset("sfx.wasp_kaput"), "Asset catalog is missing wasp impact sound.")
    _expect(assets.load_asset("sfx.wasp_kaput") != null, "Unable to load wasp impact sound.")


func _test_editor_model_previews(assets: Node) -> void:
    _expect(FileAccess.file_exists(EDITOR_PREVIEW_SCRIPT_PATH), "Editor model preview helper script should exist.")
    _expect_scene_editor_preview(PLAYER_SCENE_PATH, "VisualPivot/EditorPreview", "model.sammy.animated", 0.0, "")
    _expect_scene_editor_preview(WASP_PICKUP_SCENE_PATH, "EditorPreview", "model.wasp1", 0.05, WASP_TYPE_2_PATH, NodePath(".."))
    _expect_scene_editor_preview(WASP_PROJECTILE_SCENE_PATH, "EditorPreview", "model.wasp1", 0.0, WASP_TYPE_2_PATH)
    _expect_scene_editor_preview(BOOST_PICKUP_SCENE_PATH, "EditorPreview", "model.boost", 0.035, "")
    _expect_editor_preview_forces_double_sided_materials(assets)
    await _expect_editor_preview_applies_static_pose(assets)

    await _expect_editor_preview_removed_at_runtime(PLAYER_SCENE_PATH, "VisualPivot/EditorPreview")
    await _expect_editor_preview_removed_at_runtime(WASP_PICKUP_SCENE_PATH, "EditorPreview")
    await _expect_editor_preview_removed_at_runtime(WASP_PROJECTILE_SCENE_PATH, "EditorPreview")
    await _expect_editor_preview_removed_at_runtime(BOOST_PICKUP_SCENE_PATH, "EditorPreview")


func _expect_scene_editor_preview(scene_path: String, preview_path: String, expected_asset_id: String, expected_ground_clearance: float, expected_wasp_type_path: String, expected_wasp_source_path: NodePath = NodePath("")) -> void:
    var scene := load(scene_path) as PackedScene
    _expect(scene != null, "Scene with editor preview should load: %s" % scene_path)
    if scene == null:
        return

    var instance := scene.instantiate()
    var preview := instance.get_node_or_null(preview_path)
    _expect(preview != null, "Scene should serialize an editor preview node: %s/%s" % [scene_path, preview_path])
    if preview != null:
        var preview_script := preview.get_script() as Script
        _expect(preview_script != null and preview_script.resource_path == EDITOR_PREVIEW_SCRIPT_PATH, "Editor preview should use the shared preview helper: %s/%s" % [scene_path, preview_path])
        _expect(String(preview.get("asset_id")) == expected_asset_id, "Editor preview should target the expected asset: %s" % scene_path)
        _expect(is_equal_approx(float(preview.get("visual_ground_clearance")), expected_ground_clearance), "Editor preview should preserve its configured ground clearance: %s" % scene_path)
        _expect(bool(preview.get("force_double_sided")), "Editor preview should render extracted one-sided meshes double-sided: %s" % scene_path)
        _expect(String(preview.get("static_pose_action")).is_empty(), "Editor preview should default to the asset catalog static pose action: %s" % scene_path)
        if not expected_wasp_type_path.is_empty():
            var preview_wasp_type := preview.get("wasp_type") as Resource
            _expect(preview_wasp_type != null and preview_wasp_type.resource_path == expected_wasp_type_path, "Wasp editor preview should expose the fallback wasp type: %s" % scene_path)
        if not expected_wasp_source_path.is_empty():
            _expect(preview.get("wasp_type_source_path") == expected_wasp_source_path, "Wasp pickup preview should follow the parent wasp type override.")
    instance.free()


func _expect_editor_preview_forces_double_sided_materials(assets: Node) -> void:
    var preview_script: GDScript = load(EDITOR_PREVIEW_SCRIPT_PATH)
    _expect(assets != null and preview_script != null, "Editor preview double-sided material test needs the asset service and preview helper.")
    if assets == null or preview_script == null:
        return

    var model_root := Node3D.new()
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    var material := StandardMaterial3D.new()
    material.cull_mode = BaseMaterial3D.CULL_BACK
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh.material = material
    mesh_instance.mesh = mesh
    model_root.add_child(mesh_instance)
    var preview_helper: Node = preview_script.new()
    preview_helper.call("_force_preview_materials_double_sided", model_root)
    _expect(_model_materials_use_cull_mode(model_root, BaseMaterial3D.CULL_DISABLED), "Editor previews should disable culling so flipped or one-sided extracted faces remain visible from above and below.")
    _expect(_model_uses_transparency_mode(model_root, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS), "Editor previews should use alpha depth pre-pass for transparent imported skins so wasp bodies do not sort through themselves.")
    model_root.queue_free()
    preview_helper.queue_free()


func _expect_editor_preview_applies_static_pose(assets: Node) -> void:
    var wasp_scene := assets.load_asset("model.wasp1") as PackedScene
    var preview_script: GDScript = load(EDITOR_PREVIEW_SCRIPT_PATH)
    _expect(wasp_scene != null and preview_script != null, "Editor static-pose test needs the wasp model and preview helper.")
    if wasp_scene == null or preview_script == null:
        return

    var wasp_model := wasp_scene.instantiate() as Node3D
    var preview_helper: Node = preview_script.new()
    var wasp_type := load(WASP_TYPE_2_PATH) as Resource
    preview_helper.set("asset_id", "model.wasp1")
    preview_helper.set("_preview_instance", wasp_model)
    root.add_child(wasp_model)
    preview_helper.call("_apply_wasp_skin", assets, wasp_type)
    preview_helper.call("_enforce_preview_state", assets)
    _expect(is_equal_approx(_model_blend_shape_value(wasp_model, "stand01"), 1.0), "Editor previews should freeze the first default stand frame instead of the invalid all-zero morph base pose.")
    _expect(is_equal_approx(_model_blend_shape_value(wasp_model, "walk01"), 0.0), "Editor static stand pose should not accidentally apply walk frames.")
    _expect(_model_uses_transparency_mode(wasp_model, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR), "Wasp editor previews should keep the wasp skin color key as a binary cutout.")
    wasp_model.queue_free()
    preview_helper.queue_free()
    await process_frame


func _expect_editor_preview_removed_at_runtime(scene_path: String, preview_path: String) -> void:
    var scene := load(scene_path) as PackedScene
    if scene == null:
        return

    var instance := scene.instantiate()
    instance.set_physics_process(false)
    root.add_child(instance)
    await process_frame
    _expect(instance.get_node_or_null(preview_path) == null, "Editor preview should remove itself at runtime: %s/%s" % [scene_path, preview_path])
    instance.queue_free()
    await process_frame


func _test_animation_libraries() -> void:
    _expect_animation_library(
            "res://assets/animations/suricat1_clips.tres",
            ["stand", "walkA", "walkAB", "walkB", "sautA", "sautB", "sautC", "tirA", "tirB", "turn", "death", "kaputt", "finkaputt", "Iwin", "loopjambes", "salut"],
            ["stand", "walkB", "turn"]
    )
    _expect_animation_library(
            "res://assets/animations/rasta_clips.tres",
            ["stand", "AltStand", "rugit", "attack", "hit", "walk", "run", "death"],
            ["stand", "walk", "run"]
    )
    _expect_animation_library(
            "res://assets/animations/punk_clips.tres",
            ["stand", "AltStand", "rugit", "attack", "hit", "walk", "run", "death"],
            ["stand", "walk", "run"]
    )
    _expect_animation_library("res://assets/animations/boost_clips.tres", ["stand"], ["stand"])
    _expect_animation_library("res://assets/animations/cactus1_clips.tres", ["stand"], ["stand"])
    _expect_animation_library("res://assets/animations/wasp1_clips.tres", ["stand", "walk", "death"], ["stand", "walk"])
    _expect_clip_length("res://assets/animations/suricat1_clips.tres", "sautA", 100.0 / (30.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/suricat1_clips.tres", "tirA", 100.0 / (20.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/suricat1_clips.tres", "turn", 100.0 / (14.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/rasta_clips.tres", "attack", 100.0 / (6.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/punk_clips.tres", "stand", 100.0 / (3.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/wasp1_clips.tres", "stand", 100.0 / (3.0 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/wasp1_clips.tres", "walk", 100.0 / (0.5 * 16.0 * 1.12))
    _expect_clip_length("res://assets/animations/wasp1_clips.tres", "death", 100.0 / (6.0 * 16.0 * 1.12))


func _expect_animation_library(path: String, expected_clips: Array[String], looping_clips: Array[String]) -> void:
    var library := load(path) as AnimationLibrary
    _expect(library != null, "Unable to load generated animation library: %s" % path)
    if library == null:
        return

    for clip_name in expected_clips:
        _expect(library.has_animation(clip_name), "Generated library %s is missing clip: %s" % [path, clip_name])
        if library.has_animation(clip_name):
            var animation := library.get_animation(clip_name)
            _expect(animation.get_track_count() > 0, "Generated clip should contain morph-target tracks: %s/%s" % [path, clip_name])
            _expect(animation.track_get_interpolation_type(0) == Animation.INTERPOLATION_LINEAR, "Generated clip should smoothly interpolate morph frames: %s/%s" % [path, clip_name])
            if looping_clips.has(clip_name):
                _expect(animation.loop_mode == Animation.LOOP_LINEAR, "Generated clip should loop: %s/%s" % [path, clip_name])
                _expect_loop_wrap_pose(animation, path, clip_name)
    _expect(not library.has_animation("toto"), "Placeholder toto ranges should not become gameplay clips: %s" % path)
    _expect(not library.has_animation("base"), "Placeholder base ranges should not become gameplay clips: %s" % path)
    _expect(not library.has_animation("walk_trans"), "Placeholder transition ranges should not become gameplay clips: %s" % path)


func _expect_loop_wrap_pose(animation: Animation, path: String, clip_name: String) -> void:
    if animation.get_track_count() == 0:
        return

    var first_last_mismatch_count := 0
    for track_index in animation.get_track_count():
        var key_count := animation.track_get_key_count(track_index)
        _expect(key_count >= 2, "Looping clip should have enough keys to wrap smoothly: %s/%s" % [path, clip_name])
        if key_count < 2:
            continue

        var first_key_value = animation.track_get_key_value(track_index, 0)
        var last_key_index := key_count - 1
        var last_key_time := animation.track_get_key_time(track_index, last_key_index)
        var last_key_value = animation.track_get_key_value(track_index, last_key_index)
        _expect(absf(last_key_time - animation.length) < 0.001, "Looping clip should key the source first pose at the clip end: %s/%s" % [path, clip_name])
        if first_key_value != last_key_value:
            first_last_mismatch_count += 1

    _expect(first_last_mismatch_count == 0, "Looping clip should return to its source first pose before Godot wraps playback: %s/%s" % [path, clip_name])


func _expect_clip_length(path: String, clip_name: String, expected_length: float) -> void:
    var library := load(path) as AnimationLibrary
    _expect(library != null, "Unable to load generated animation library for length check: %s" % path)
    if library == null:
        return
    _expect(library.has_animation(clip_name), "Generated library %s is missing timed clip: %s" % [path, clip_name])
    if not library.has_animation(clip_name):
        return
    var animation := library.get_animation(clip_name)
    _expect(absf(animation.length - expected_length) < 0.01, "Generated clip should use original WDL timing: %s/%s" % [path, clip_name])


func _test_wmb_manifest() -> void:
    var manifest_script: GDScript = load(WMB_MANIFEST_SCRIPT_PATH)
    var manifest: RefCounted = manifest_script.new()
    var err: Error = manifest.load_file("res://assets/metadata/wmb_manifest.json")
    _expect(err == OK, "Unable to parse copied WMB manifest: %s" % error_string(err))
    _expect(int(manifest.get_counts().get("external_wmb_files", 0)) > 0, "WMB manifest did not expose external level counts.")
    _expect(manifest.has_level("10001.wmb"), "WMB manifest lookup failed for 10001.wmb.")


func _test_model_skin_alpha() -> void:
    _expect(_png_is_fully_opaque("res://assets/models/Punk/skins/Punk_skin0.png"), "Punk RGB565 skin must stay opaque; black texels are painted detail.")
    _expect(_png_is_fully_opaque("res://assets/models/rasta/skins/rasta_skin0.png"), "Rasta RGB565 skin must stay opaque; black texels are painted detail.")
    _expect(_text_file_lacks("res://assets/models/Punk/Punk_animated.gltf", "\"alphaMode\""), "Punk material should not import as alpha masked.")
    _expect(_text_file_lacks("res://assets/models/rasta/rasta_animated.gltf", "\"alphaMode\""), "Rasta material should not import as alpha masked.")
    _expect(_text_file_contains("res://assets/models/wasp1/wasp1.gltf", "\"alphaMode\": \"BLEND\""), "Static wasp material should import with alpha blending enabled.")
    _expect(_text_file_contains("res://assets/models/wasp1/wasp1_animated.gltf", "\"alphaMode\": \"BLEND\""), "Animated wasp material should import with alpha blending enabled.")
    _expect(_wasp_gltf_has_split_leg_surface("res://assets/models/wasp1/wasp1.gltf"), "Static wasp GLTF should split mirrored/lower-leg triangles onto their own material.")
    _expect(_wasp_gltf_has_split_leg_surface("res://assets/models/wasp1/wasp1_animated.gltf"), "Animated wasp GLTF should split mirrored/lower-leg triangles onto their own material.")
    for skin_index in range(7):
        var skin_path := "res://assets/models/wasp1/skins/wasp1_skin%d.png" % skin_index
        var leg_skin_path := "res://assets/models/wasp1/skins/legs/wasp1_skin%d_legs.png" % skin_index
        var source_skin_path := "res://extract-sammy-assets/extracted/godot/models/wasp1/skins/wasp1_skin%d.png" % skin_index
        var import_path := "%s.import" % skin_path
        var leg_import_path := "%s.import" % leg_skin_path
        _expect(_png_has_transparent_pixels(skin_path), "Wasp skin %d should preserve fully transparent unused color-key pixels." % skin_index)
        _expect(_png_source_black_pixels_are_transparent(source_skin_path, skin_path), "Wasp skin %d should keep source exact-black MDL color-key texels transparent instead of filling leg backgrounds." % skin_index)
        _expect(_png_count_translucent_near_black_pixels(skin_path) == 0, "Wasp skin %d should not turn transparent color-key areas into semi-transparent black geometry." % skin_index)
        _expect(_png_count_translucent_near_white_pixels(skin_path) == 0, "Wasp skin %d should not contain semi-transparent white texels in color-keyed regions." % skin_index)
        _expect(_png_count_opaque_near_black_pixels_in_wasp_lower_leg_uv(skin_path) >= 25, "Wasp skin %d should preserve opaque dark lower-leg strokes without restoring the color-key background." % skin_index)
        _expect(_png_leg_paint_pixels_are_black(skin_path), "Wasp skin %d should not leave white lower-leg pixels on the mirrored side." % skin_index)
        _expect(_png_count_opaque_near_black_pixels(skin_path) >= 40, "Wasp skin %d should preserve opaque black body and leg detail pixels." % skin_index)
        _expect(_text_file_contains(import_path, "\"vram_texture\": false"), "Wasp skin %d should avoid VRAM compression so thin black details do not wash out." % skin_index)
        _expect(_text_file_contains(import_path, "compress/mode=0"), "Wasp skin %d should import losslessly." % skin_index)
        _expect(_text_file_contains(import_path, "mipmaps/generate=false"), "Wasp skin %d should avoid mipmap blends that make transparent cutouts look semi-white." % skin_index)
        _expect(_text_file_contains(import_path, "process/fix_alpha_border=false"), "Wasp skin %d should not bleed nearby body colors into keyed black model texels." % skin_index)
        _expect(_png_has_transparent_pixels(leg_skin_path), "Wasp leg skin %d should keep keyed backgrounds fully transparent." % skin_index)
        _expect(_png_count_opaque_near_black_pixels(leg_skin_path) >= 500, "Wasp leg skin %d should provide black mirrored/lower-leg paint for the split material." % skin_index)
        _expect(_png_count_opaque_non_black_pixels(leg_skin_path) == 0, "Wasp leg skin %d should not contain white or body-colored leg texels." % skin_index)
        _expect(_png_opaque_pixels_stay_in_wasp_lower_leg_uv(leg_skin_path), "Wasp leg skin %d should not blacken shared body/back atlas regions." % skin_index)
        _expect(_png_count_translucent_near_black_pixels(leg_skin_path) == 0, "Wasp leg skin %d should not contain semi-transparent black backgrounds." % skin_index)
        _expect(_png_count_translucent_near_white_pixels(leg_skin_path) == 0, "Wasp leg skin %d should not contain semi-transparent white backgrounds." % skin_index)
        _expect(_text_file_contains(leg_import_path, "\"vram_texture\": false"), "Wasp leg skin %d should avoid VRAM compression." % skin_index)
        _expect(_text_file_contains(leg_import_path, "compress/mode=0"), "Wasp leg skin %d should import losslessly." % skin_index)
        _expect(_text_file_contains(leg_import_path, "mipmaps/generate=false"), "Wasp leg skin %d should avoid mipmap blends." % skin_index)
        _expect(_text_file_contains(leg_import_path, "process/fix_alpha_border=false"), "Wasp leg skin %d should not bleed colors into keyed texels." % skin_index)


func _wasp_gltf_has_split_leg_surface(path: String) -> bool:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        return false
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    var data := parsed as Dictionary
    var meshes := data.get("meshes", []) as Array
    var materials := data.get("materials", []) as Array
    if meshes.is_empty() or materials.is_empty():
        return false
    var mesh := meshes[0] as Dictionary
    var primitives := mesh.get("primitives", []) as Array
    var accessors := data.get("accessors", []) as Array
    if primitives.size() != 2 or accessors.is_empty():
        return false
    var found_leg_material := false
    var body_index_count := 0
    var leg_index_count := 0
    for primitive_index in range(primitives.size()):
        var primitive_value = primitives[primitive_index]
        var primitive := primitive_value as Dictionary
        var index_accessor_index := int(primitive.get("indices", -1))
        if index_accessor_index < 0 or index_accessor_index >= accessors.size():
            return false
        var index_accessor := accessors[index_accessor_index] as Dictionary
        if primitive_index == 0:
            body_index_count = int(index_accessor.get("count", 0))
        elif primitive_index == 1:
            leg_index_count = int(index_accessor.get("count", 0))
        var material_index := int(primitive.get("material", -1))
        if material_index < 0 or material_index >= materials.size():
            continue
        var material := materials[material_index] as Dictionary
        if String(material.get("name", "")).contains("leg"):
            found_leg_material = true
    return found_leg_material and body_index_count == 237 and leg_index_count == 51


func _png_is_fully_opaque(path: String) -> bool:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return false
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return false
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x, y).a < 1.0:
                return false
    return true


func _png_has_transparent_pixels(path: String) -> bool:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return false
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return false
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x, y).a <= 0.0:
                return true
    return false


func _png_count_opaque_near_black_pixels(path: String) -> int:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return 0
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return 0
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a >= 1.0 and pixel.r <= 0.16 and pixel.g <= 0.16 and pixel.b <= 0.16:
                count += 1
    return count


func _png_count_opaque_non_black_pixels(path: String) -> int:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return 0
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return 0
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a >= 1.0 and (pixel.r > 0.01 or pixel.g > 0.01 or pixel.b > 0.01):
                count += 1
    return count


func _png_opaque_pixels_stay_in_wasp_lower_leg_uv(path: String) -> bool:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return false
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return false
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a >= 1.0 and not _is_wasp_leg_surface_uv_pixel(x, y):
                return false
    return true


func _png_source_black_pixels_are_transparent(source_path: String, repaired_path: String) -> bool:
    var source_bytes := FileAccess.get_file_as_bytes(source_path)
    var repaired_bytes := FileAccess.get_file_as_bytes(repaired_path)
    if source_bytes.is_empty() or repaired_bytes.is_empty():
        return false
    var source_image := Image.new()
    var repaired_image := Image.new()
    if source_image.load_png_from_buffer(source_bytes) != OK:
        return false
    if repaired_image.load_png_from_buffer(repaired_bytes) != OK:
        return false
    if source_image.get_size() != repaired_image.get_size():
        return false
    for y in source_image.get_height():
        for x in source_image.get_width():
            var source_pixel := source_image.get_pixel(x, y)
            if source_pixel.r <= 0.0 and source_pixel.g <= 0.0 and source_pixel.b <= 0.0:
                if repaired_image.get_pixel(x, y).a > 0.0:
                    return false
    return true


func _png_count_opaque_near_black_pixels_in_wasp_lower_leg_uv(path: String) -> int:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return 0
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return 0
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            if not _is_wasp_lower_leg_uv_pixel(x, y):
                continue
            var pixel := image.get_pixel(x, y)
            if pixel.a >= 1.0 and pixel.r <= 0.16 and pixel.g <= 0.16 and pixel.b <= 0.16:
                count += 1
    return count


func _png_leg_paint_pixels_are_black(path: String) -> bool:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return false
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return false
    for y in image.get_height():
        for x in image.get_width():
            if not _is_wasp_lower_leg_uv_pixel(x, y):
                continue
            var pixel := image.get_pixel(x, y)
            if pixel.a >= 1.0 and _is_wasp_leg_paint_pixel(pixel) and (pixel.r > 0.16 or pixel.g > 0.16 or pixel.b > 0.16):
                return false
    return true


func _is_wasp_leg_paint_pixel(pixel: Color) -> bool:
    var channel_max = max(pixel.r, max(pixel.g, pixel.b))
    var channel_min = min(pixel.r, min(pixel.g, pixel.b))
    return channel_max <= 0.36 or channel_max - channel_min <= 0.18


func _is_wasp_lower_leg_uv_pixel(x: int, y: int) -> bool:
    if (x >= 40 and y >= 45) or (x >= 34 and y >= 51):
        return true
    var point := Vector2(float(x), float(y))
    return (
            _point_in_triangle(point, Vector2(43.0, 46.0), Vector2(55.0, 63.0), Vector2(56.0, 46.0))
            or _point_in_triangle(point, Vector2(42.0, 63.0), Vector2(55.0, 63.0), Vector2(43.0, 46.0))
            or _point_in_triangle(point, Vector2(56.0, 46.0), Vector2(55.0, 63.0), Vector2(43.0, 46.0))
            or _point_in_triangle(point, Vector2(43.0, 46.0), Vector2(55.0, 63.0), Vector2(42.0, 63.0))
    )


func _is_wasp_leg_surface_uv_pixel(x: int, y: int) -> bool:
    if _is_wasp_lower_leg_uv_pixel(x, y):
        return true
    var point := Vector2(float(x), float(y))
    return (
            _point_in_triangle(point, Vector2(25.0, 30.0), Vector2(34.0, 12.0), Vector2(36.0, 22.0))
            or _point_in_triangle(point, Vector2(25.0, 32.0), Vector2(36.0, 24.0), Vector2(37.0, 32.0))
            or _point_in_triangle(point, Vector2(34.0, 20.0), Vector2(47.0, 7.0), Vector2(34.0, 12.0))
            or _point_in_triangle(point, Vector2(47.0, 7.0), Vector2(36.0, 22.0), Vector2(34.0, 12.0))
            or _point_in_triangle(point, Vector2(25.0, 32.0), Vector2(36.0, 32.0), Vector2(34.0, 22.0))
            or _point_in_triangle(point, Vector2(25.0, 30.0), Vector2(34.0, 20.0), Vector2(34.0, 12.0))
            or _point_in_triangle(point, Vector2(36.0, 24.0), Vector2(55.0, 21.0), Vector2(37.0, 32.0))
            or _point_in_triangle(point, Vector2(25.0, 32.0), Vector2(37.0, 32.0), Vector2(40.0, 43.0))
            or _point_in_triangle(point, Vector2(25.0, 32.0), Vector2(40.0, 43.0), Vector2(36.0, 32.0))
    )


func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
    var denominator := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
    if is_zero_approx(denominator):
        return false
    var weight_a := ((b.y - c.y) * (point.x - c.x) + (c.x - b.x) * (point.y - c.y)) / denominator
    var weight_b := ((c.y - a.y) * (point.x - c.x) + (a.x - c.x) * (point.y - c.y)) / denominator
    var weight_c := 1.0 - weight_a - weight_b
    return weight_a >= -0.055 and weight_b >= -0.055 and weight_c >= -0.055


func _png_count_translucent_near_black_pixels(path: String) -> int:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return 0
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return 0
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a > 0.0 and pixel.a < 1.0 and pixel.r <= 0.16 and pixel.g <= 0.16 and pixel.b <= 0.16:
                count += 1
    return count


func _png_count_translucent_near_white_pixels(path: String) -> int:
    var bytes := FileAccess.get_file_as_bytes(path)
    if bytes.is_empty():
        return 0
    var image := Image.new()
    var err := image.load_png_from_buffer(bytes)
    if err != OK:
        return 0
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a > 0.0 and pixel.a < 1.0 and pixel.r >= 0.94 and pixel.g >= 0.94 and pixel.b >= 0.94:
                count += 1
    return count


func _text_file_lacks(path: String, needle: String) -> bool:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    return not file.get_as_text().contains(needle)


func _text_file_contains(path: String, needle: String) -> bool:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    return file.get_as_text().contains(needle)


func _test_main_scene() -> void:
    var main_scene: PackedScene = load(MAIN_SCENE_PATH)
    _expect(main_scene != null, "Unable to load main scene.")
    if main_scene == null:
        return

    var main: Node = main_scene.instantiate()
    _expect(main.get_node_or_null("PrototypeWorld") != null, "Main scene should instance PrototypeWorld in the editor.")
    root.add_child(main)
    await process_frame
    main.queue_free()
    await process_frame


func _test_wasp_resources(assets: Node) -> void:
    var expected_damage := [0, 3, 2, 1, 1, 4, 6, 1]
    var expected_skin := [0, 1, 2, 3, 4, 5, 6, 7]
    var expected_multi_count := [0, 1, 1, 3, 3, 1, 1, 1]
    var expected_homing := [false, true, false, false, true, true, true, false]
    var expected_fire_speed := [0.0, 1.0, 2.2, 1.5, 1.2, 1.2, 1.0, 3.0]
    var expected_speed := [0.0, 4.48, 14.0, 14.0, 14.0, 5.04, 5.376, 14.0]
    for type_id in range(1, WASP_TYPE_PATHS.size()):
        var wasp_type: Resource = load(WASP_TYPE_PATHS[type_id])
        _expect(wasp_type != null, "Wasp type %d resource should load." % type_id)
        if wasp_type == null:
            continue
        _expect(StringName(wasp_type.get("id")) == StringName("type_%d" % type_id), "Wasp type %d should expose a stable resource id." % type_id)
        _expect(int(wasp_type.get("wdl_type_id")) == type_id, "Wasp type %d should preserve the original WDL type id." % type_id)
        _expect(int(wasp_type.get("damage")) == expected_damage[type_id], "Wasp type %d should preserve original WDL poison/damage." % type_id)
        _expect(int(wasp_type.get("skin_index")) == expected_skin[type_id], "Wasp type %d should use the original 1-based WDL skin number." % type_id)
        _expect(int(wasp_type.get("multi_shot_count")) == expected_multi_count[type_id], "Wasp type %d should preserve original player-shot count." % type_id)
        _expect(bool(wasp_type.get("homing")) == expected_homing[type_id], "Wasp type %d should preserve original homing/scan behavior." % type_id)
        _expect(is_equal_approx(float(wasp_type.get("fire_animation_speed")), expected_fire_speed[type_id]), "Wasp type %d should preserve original PlayerAnimSpeedDebutTir multiplier." % type_id)
        _expect(absf(float(wasp_type.get("speed")) - expected_speed[type_id]) < 0.001, "Wasp type %d should preserve original speed ratio against type 2." % type_id)
        _expect(float(wasp_type.get("lifetime_seconds")) > 0.0, "Wasp type %d should have a positive lifetime." % type_id)
        if assets != null and assets.has_method("load_wasp_skin_texture"):
            _expect(assets.call("load_wasp_skin_texture", int(wasp_type.get("skin_index"))) != null, "Wasp type %d skin texture should load from the runtime asset slice." % type_id)
        if assets != null and assets.has_method("load_wasp_leg_skin_texture"):
            _expect(assets.call("load_wasp_leg_skin_texture", int(wasp_type.get("skin_index"))) != null, "Wasp type %d leg texture should load from the runtime asset slice." % type_id)
    if assets != null and assets.has_method("apply_wasp_skin"):
        var wasp_scene := assets.load_asset("model.wasp1") as PackedScene
        _expect(wasp_scene != null, "Wasp model should load for model-skin material validation.")
        if wasp_scene != null:
            var wasp_model := wasp_scene.instantiate() as Node3D
            _expect(bool(assets.call("apply_wasp_skin", wasp_model, 1)), "Applying a wasp skin should succeed for transparent material validation.")
            var expected_leg_texture: Texture2D = null
            if assets.has_method("load_wasp_leg_skin_texture"):
                expected_leg_texture = assets.call("load_wasp_leg_skin_texture", 1) as Texture2D
            _expect(expected_leg_texture != null and _model_uses_texture(wasp_model, expected_leg_texture), "Applying a wasp skin should assign the black leg mask to the split leg surface.")
            _expect(expected_leg_texture != null and _model_surface_with_texture_uses_shading_mode(wasp_model, expected_leg_texture, BaseMaterial3D.SHADING_MODE_UNSHADED), "Wasp leg masks should render unshaded so black legs do not turn gray or white under scene lighting.")
            _expect(_model_uses_transparency_mode(wasp_model, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR), "Runtime wasp skins should use binary alpha scissor so color-key background texels stay fully transparent.")
            _expect(_model_uses_alpha_scissor_threshold(wasp_model, 0.5), "Runtime wasp skins should cut out the exact-black background instead of blending it over the scene.")
            _expect(_model_uses_texture_filter(wasp_model, BaseMaterial3D.TEXTURE_FILTER_NEAREST), "Runtime wasp skins should use nearest filtering so black legs stay crisp instead of sampling neighboring transparent texels.")
            wasp_model.queue_free()
    var type_3: Resource = load(WASP_TYPE_3_PATH)
    _expect(type_3 != null and is_equal_approx(float(type_3.get("multi_shot_interval_seconds")), 0.125), "Type 3 should preserve the original waitt 2 spacing between triple shots.")
    var type_5: Resource = load(WASP_TYPE_5_PATH)
    _expect(type_5 != null and bool(type_5.get("dive_arc")), "Type 5 should expose its original rise-then-dive arc.")


func _test_wasp_inventory() -> void:
    var inventory_script: GDScript = load(WASP_INVENTORY_SCRIPT_PATH)
    var inventory: Node = inventory_script.new()
    var type_a: Resource = load(WASP_TYPE_2_PATH)
    var type_b_script: GDScript = load("res://src/resources/wasp_type.gd")
    var type_b: Resource = type_b_script.new()
    type_b.set("id", &"type_other")
    type_b.set("damage", 1)
    type_b.set("speed", 14.0)
    type_b.set("lifetime_seconds", 8.0)

    _expect(not bool(inventory.call("has_ammo")), "Empty wasp inventory should report no ammo.")
    _expect(not bool(inventory.call("consume_ammo", 1)), "Empty wasp inventory should refuse to consume ammo.")

    inventory.call("add_ammo", type_a, 5)
    _expect(int(inventory.call("get_ammo_count")) == 5, "Adding ammo should set the ammo count.")
    _expect(inventory.call("get_current_type") == type_a, "Adding ammo should set the current type.")
    _expect(bool(inventory.call("has_ammo")), "Inventory should report ammo after pickup.")

    inventory.call("add_ammo", type_a, 3)
    _expect(int(inventory.call("get_ammo_count")) == 8, "Adding the same type should accumulate ammo.")

    var ejected_state := {"emitted": false, "replaced": null}
    inventory.connect("active_wasps_ejected", func(replaced: Resource) -> void:
        ejected_state["emitted"] = true
        ejected_state["replaced"] = replaced)

    inventory.call("add_ammo", type_b, 4)
    _expect(bool(ejected_state["emitted"]), "Switching wasp type should emit the active_wasps_ejected signal.")
    _expect(ejected_state["replaced"] == type_a, "Eject signal should report the replaced wasp type.")
    _expect(inventory.call("get_current_type") == type_b, "Switching wasp type should replace the current type.")
    _expect(int(inventory.call("get_ammo_count")) == 4, "Switching wasp type should reset to the new ammo count.")

    _expect(bool(inventory.call("consume_ammo", 1)), "Consuming ammo should succeed when ammo is available.")
    _expect(int(inventory.call("get_ammo_count")) == 3, "Consuming ammo should decrement the count.")

    while bool(inventory.call("consume_ammo", 1)):
        pass
    _expect(int(inventory.call("get_ammo_count")) == 0, "Inventory should reach zero ammo after full drain.")
    _expect(inventory.call("get_current_type") == null, "Reaching zero ammo should clear the current wasp type.")
    _expect(not bool(inventory.call("has_ammo")), "Inventory should report no ammo after drain.")

    inventory.queue_free()


func _test_wasp_projectile_damages_enemy() -> void:
    var enemy_scene: PackedScene = load("res://scenes/enemies/punk_enemy.tscn")
    var enemy: Node = enemy_scene.instantiate()
    enemy.set("affected_by_gravity", false)
    enemy.set("max_health", 5)
    root.add_child(enemy)
    enemy.global_position = Vector3(0.0, 0.0, -3.0)
    await physics_frame

    var projectile_scene: PackedScene = load("res://scenes/weapons/wasp_projectile.tscn")
    var projectile: Node = projectile_scene.instantiate()
    var wasp_type: Resource = load(WASP_TYPE_2_PATH)
    root.add_child(projectile)
    var spawn_transform := Transform3D(Basis(), Vector3(0.0, 0.7, -2.0))
    projectile.call("configure", wasp_type, null, spawn_transform)

    _expect(int(projectile.get("collision_layer")) == PROJECTILE_LAYER, "Wasp projectile should live on the projectile collision layer.")
    _expect(int(projectile.get("collision_mask")) == WORLD_AND_CHARACTER_MASK, "Wasp projectile should detect world and character bodies.")

    for step in 60:
        if not is_instance_valid(projectile) or bool(projectile.call("is_consumed")):
            break
        await physics_frame

    _expect(int(enemy.call("get_health")) <= 5 - int(wasp_type.get("damage")), "Wasp projectile should reduce enemy health on contact.")
    _expect(not is_instance_valid(projectile) or bool(projectile.call("is_consumed")), "Wasp projectile should despawn after hitting an enemy.")

    if is_instance_valid(projectile):
        projectile.queue_free()
    if is_instance_valid(enemy):
        enemy.queue_free()
    await process_frame


func _test_wasp_projectile_behaviors() -> void:
    var projectile_scene: PackedScene = load("res://scenes/weapons/wasp_projectile.tscn")
    var type_1: Resource = load(WASP_TYPE_PATHS[1])
    var type_2: Resource = load(WASP_TYPE_2_PATH)
    var type_5: Resource = load(WASP_TYPE_5_PATH)

    var target := Node3D.new()
    target.name = "WaspHomingTarget"
    target.add_to_group("enemy")
    root.add_child(target)
    target.global_position = Vector3(2.0, 0.7, -4.0)

    var straight_projectile: Node = projectile_scene.instantiate()
    root.add_child(straight_projectile)
    straight_projectile.call("configure", type_2, null, Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)))
    var straight_visual := straight_projectile.get_node_or_null("WaspVisual") as Node3D
    _expect(straight_visual != null, "Wasp projectile should spawn the original animated wasp model visual.")
    var straight_controller := straight_projectile.call("get_animation_controller") as Node
    _expect(straight_controller != null, "Wasp projectile should attach a generated animation controller.")
    if straight_controller != null:
        _expect(bool(straight_controller.call("has_action", "walk")), "Wasp projectile animation controller should expose walk.")
        _expect(bool(straight_controller.call("has_action", "death")), "Wasp projectile animation controller should expose death.")
        _expect(String(straight_controller.call("get_current_action")) == "walk", "Wasp projectile should play the original walk cycle while flying.")
        var straight_animation_player := straight_controller.get("animation_player") as AnimationPlayer
        if straight_animation_player != null:
            _expect(is_equal_approx(straight_animation_player.speed_scale, float(type_2.get("wdl_speed_units"))), "Wasp projectile walk cycle should scale from the original SpeedWasp units.")
    var straight_before := straight_projectile.call("get_velocity") as Vector3
    straight_projectile.call("_physics_process", 0.1)
    var straight_after := straight_projectile.call("get_velocity") as Vector3
    _expect(absf(straight_after.x - straight_before.x) < 0.001, "Type 2 should remain a straight, non-homing wasp.")

    var homing_projectile: Node = projectile_scene.instantiate()
    root.add_child(homing_projectile)
    homing_projectile.call("configure", type_1, null, Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)))
    var homing_before := homing_projectile.call("get_velocity") as Vector3
    homing_projectile.call("_physics_process", 0.1)
    var homing_after := homing_projectile.call("get_velocity") as Vector3
    _expect(absf(homing_after.x) > absf(homing_before.x) + 0.01, "Type 1 should steer toward enemies inside its WDL scan range.")
    _expect(is_equal_approx(homing_after.length(), float(type_1.get("speed"))), "Homing should preserve the configured wasp speed.")

    target.remove_from_group("enemy")
    var dive_projectile: Node = projectile_scene.instantiate()
    root.add_child(dive_projectile)
    dive_projectile.call("configure", type_5, null, Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)))
    dive_projectile.call("_physics_process", 0.1)
    var climb_velocity := dive_projectile.call("get_velocity") as Vector3
    _expect(climb_velocity.y > 0.0, "Type 5 should begin with the original upward dive-wasp arc.")
    dive_projectile.call("_physics_process", 1.0)
    var dive_velocity := dive_projectile.call("get_velocity") as Vector3
    _expect(bool(dive_projectile.call("is_dive_homing_unlocked")), "Type 5 should unlock homing after its original rise/hold/level phases.")
    _expect(float(dive_projectile.call("get_pitch_degrees")) < 0.0, "Type 5 should pitch downward after its original dive delay.")
    _expect(dive_velocity.y < 0.0, "Type 5 should move downward once the dive phase starts.")

    var death_projectile: Node = projectile_scene.instantiate()
    root.add_child(death_projectile)
    death_projectile.call("configure", type_2, null, Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)))
    death_projectile.call("_despawn", false)
    _expect(bool(death_projectile.call("is_consumed")), "Consumed wasp projectile should mark itself consumed before death cleanup.")
    _expect(bool(death_projectile.call("is_death_animation_active")), "Consumed wasp projectile should play its original death animation before cleanup.")
    var death_controller := death_projectile.call("get_animation_controller") as Node
    if death_controller != null:
        _expect(String(death_controller.call("get_current_action")) == "death", "Consumed wasp projectile should switch to the original death cycle.")

    straight_projectile.queue_free()
    homing_projectile.queue_free()
    dive_projectile.queue_free()
    death_projectile.queue_free()
    target.queue_free()
    await process_frame


func _test_player_scene() -> void:
    var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
    var player: Node = player_scene.instantiate()
    root.add_child(player)
    await process_frame
    _expect(player is CharacterBody3D, "Player scene root must be CharacterBody3D.")
    _expect(player.get_script() != null, "Player scene script failed to load.")
    _expect(player.has_method("get_facing_direction"), "Player controller did not expose tank-control helpers.")
    _expect(player.get_node_or_null("CollisionShape3D") != null, "Player scene is missing collision shape.")
    _expect(int(player.get("collision_layer")) == CHARACTER_LAYER, "Player should live on the character collision layer.")
    _expect(int(player.get("collision_mask")) == WORLD_AND_CHARACTER_MASK, "Player should collide with world and other solid characters.")
    _expect(player.get_node_or_null("VisualPivot") != null, "Player scene is missing visual pivot.")
    var sammy_model := player.get_node_or_null("VisualPivot/SammyModel") as Node3D
    _expect(sammy_model != null, "Player scene did not spawn the Sammy model.")
    if sammy_model != null:
        _expect(sammy_model.rotation_degrees.is_equal_approx(Vector3(0.0, 90.0, 0.0)), "Player visual should apply the Acknex character forward correction.")
        var assets := root.get_node_or_null("Assets")
        if assets != null:
            var bounds: AABB = assets.get_model_global_bounds(sammy_model)
            _expect(absf(bounds.position.y - (player as Node3D).global_position.y) < 0.01, "Player visual should be grounded on the player floor.")
        var animation_controller := sammy_model.get_node_or_null("ModelAnimationController")
        _expect(animation_controller != null, "Player model should have a generated animation controller.")
        if animation_controller != null:
            _expect(bool(animation_controller.call("has_action", "stand")), "Player animation controller should expose stand.")
            _expect(bool(animation_controller.call("has_action", "walkB")), "Player animation controller should expose original walkB.")
            _expect(bool(animation_controller.call("has_action", "tirA")), "Player animation controller should expose original tirA.")
            _expect(not String(animation_controller.call("get_current_action")).is_empty(), "Player animation controller should select an initial action.")
            _expect(bool(animation_controller.call("play_action", "walkB")), "Player animation controller should play generated walkB.")
            var animation_player := animation_controller.get("animation_player") as AnimationPlayer
            if animation_player != null:
                animation_player.seek(0.25, true)
                _expect(bool(animation_controller.call("play_action", "walkB", -1.0, 2.0)), "Player animation controller should update active walk speed.")
                _expect(animation_player.current_animation_position >= 0.24, "Changing active walk speed should not restart the walk cycle.")
                _expect(is_equal_approx(animation_player.speed_scale, 2.0), "Changing active walk speed should update AnimationPlayer speed scale.")
    if player.has_method("get_facing_direction"):
        _expect((player.call("get_facing_direction") as Vector3).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Player should move along its facing direction by default.")
        var camera_script: GDScript = load(CAMERA_SCRIPT_PATH)
        var parity_camera := Camera3D.new()
        parity_camera.name = "QuickTurnParityCamera"
        parity_camera.set_script(camera_script)
        root.add_child(parity_camera)
        parity_camera.target_path = parity_camera.get_path_to(player)
        parity_camera.call("reset_to_target")
        var initial_camera_offset := parity_camera.call("_get_follow_offset") as Vector3
        _expect(String(player.get("quick_turn_sound_asset_id")) == "sfx.quick_turn", "Quick turn should use the original Blouit_son asset.")
        player.call("apply_quick_turn")
        _expect(player.has_method("is_quick_turning"), "Player controller should expose quick-turn state for parity validation.")
        _expect(bool(player.call("is_quick_turning")), "Quick turn should begin a staged original-style turn instead of snapping instantly.")
        var audio := root.get_node_or_null("Audio")
        if audio != null:
            var quick_turn_sfx_player := audio.get_node_or_null("SfxPlayer0") as AudioStreamPlayer
            _expect(quick_turn_sfx_player != null and quick_turn_sfx_player.stream != null, "Quick turn should play the original Blouit_son through the audio service.")
        var quick_turn_controller := player.call("get_animation_controller") as Node
        if quick_turn_controller != null:
            _expect(String(quick_turn_controller.call("get_current_action")) == "turn", "Quick turn should restart Sammy's original turn animation.")
            var quick_turn_animation_player := quick_turn_controller.get("animation_player") as AnimationPlayer
            if quick_turn_animation_player != null:
                _expect(is_equal_approx(quick_turn_animation_player.speed_scale, 2.0), "Quick turn should play the turn animation at PlayerAnimSpeedTurn * 2.")
        player.call("_advance_quick_turn", 1.0 / 60.0)
        var partial_facing := player.call("get_facing_direction") as Vector3
        _expect(partial_facing.x < -0.01, "Quick turn should start in the original left-turn direction before reaching the 180-degree outcome.")
        var partial_camera_offset := parity_camera.call("_get_follow_offset") as Vector3
        _expect(partial_camera_offset.x > initial_camera_offset.x, "Camera follow offset should begin around the matching side of Sammy during quick turn.")
        for quick_turn_step in range(120):
            if not bool(player.call("is_quick_turning")):
                break
            player.call("_advance_quick_turn", 1.0 / 60.0)
        _expect(not bool(player.call("is_quick_turning")), "Quick turn should finish after the original easing loop converges.")
        _expect((player.call("get_facing_direction") as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "Quick turn should rotate Sammy 180 degrees.")
        player.call("apply_quick_turn")
        _expect(bool(player.call("is_quick_turning")), "A second quick turn should start after the first one finishes.")
        player.call("_advance_quick_turn", 1.0 / 60.0)
        for second_quick_turn_step in range(120):
            if not bool(player.call("is_quick_turning")):
                break
            player.call("_advance_quick_turn", 1.0 / 60.0)
        _expect(not bool(player.call("is_quick_turning")), "A second quick turn should not get stuck after yaw wrapping.")
        _expect((player.call("get_facing_direction") as Vector3).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Second quick turn should return Sammy to the original facing direction.")
        parity_camera.queue_free()
        var fire_requests := int(player.call("get_fire_request_count"))
        var controller := player.call("get_animation_controller") as Node
        var action_before_empty_fire := String(controller.call("get_current_action")) if controller != null else ""
        var children_before_empty_fire := root.get_child_count()
        _expect(not bool(player.call("fire_wasp")), "Fire action should be rejected when Sammy has no wasp ammo.")
        _expect(int(player.call("get_fire_request_count")) == fire_requests, "Rejected no-ammo fire should not increment accepted fire count.")
        _expect(root.get_child_count() == children_before_empty_fire, "Rejected no-ammo fire should not spawn a wasp projectile.")
        if controller != null:
            _expect(String(controller.call("get_current_action")) == action_before_empty_fire, "Rejected no-ammo fire should not start Sammy's tirA animation.")
        var player_assets := root.get_node_or_null("Assets")
        if audio != null and player_assets != null:
            _expect(_audio_service_has_stream(audio, player_assets.load_asset("sfx.error") as AudioStream), "Rejected no-ammo fire should play original Error1_son.")
        _expect(player.has_method("get_wasp_inventory"), "Player controller should expose a wasp inventory accessor.")
        if player.has_method("get_wasp_inventory"):
            var inventory: Node = player.call("get_wasp_inventory")
            _expect(inventory != null, "Player should auto-spawn a WaspInventory child node.")
            if inventory != null:
                _expect(int(inventory.call("get_ammo_count")) == 0, "Firing without ammo should not decrement below zero.")
                _expect(not bool(inventory.call("has_ammo")), "Player should start without wasp ammo.")
                var wasp_type: Resource = load(WASP_TYPE_2_PATH)
                inventory.call("add_ammo", wasp_type, 3)
                var children_before := root.get_child_count()
                var fire_spawn_delay := float(player.call("_get_wasp_fire_spawn_delay_seconds", wasp_type))
                var fire_recovery := float(player.call("_get_wasp_fire_recovery_seconds"))
                _expect(fire_spawn_delay > 0.0, "Type 2 wasp fire should expose the original tirA spawn delay.")
                _expect(fire_recovery > 0.0, "Wasp fire should expose a recovery cooldown after projectile spawn.")
                _expect(player.has_method("is_jump_fire_blocked"), "Player controller should expose jump fire-block state for parity validation.")
                var jump_block_action_before := String(controller.call("get_current_action")) if controller != null else ""
                var fire_requests_before_jump_block := int(player.call("get_fire_request_count"))
                player.set("_jump_fire_blocked", true)
                _expect(bool(player.call("is_jump_fire_blocked")), "Player should mark wasp fire blocked while in the jump state.")
                _expect(not bool(player.call("fire_wasp")), "Fire action should be rejected while Sammy is in the original jump state.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests_before_jump_block, "Rejected jump-state fire should not increment accepted fire count.")
                _expect(int(inventory.call("get_ammo_count")) == 3, "Rejected jump-state fire should leave wasp ammo unchanged.")
                _expect(root.get_child_count() == children_before, "Rejected jump-state fire should not spawn a wasp projectile.")
                if controller != null:
                    _expect(String(controller.call("get_current_action")) == jump_block_action_before, "Rejected jump-state fire should not start Sammy's tirA animation.")
                player.set("_jump_fire_blocked", false)
                _expect(not bool(player.call("is_jump_fire_blocked")), "Player should allow wasp fire again after the jump state clears.")
                _expect(player.has_method("is_landing_movement_locked"), "Player controller should expose landing movement lock state for parity validation.")
                var landing_lock_duration := float(player.call("_get_landing_movement_lock_seconds", 0.0, 0.0, false))
                var fast_landing_lock_duration := float(player.call("_get_landing_movement_lock_seconds", 1.0, 0.0, false))
                _expect(landing_lock_duration > 0.0, "Landing should expose a temporary movement lock from the original FinJump state.")
                _expect(fast_landing_lock_duration < landing_lock_duration, "Held movement should use the original faster FinJump recovery.")
                var fire_requests_before_landing_block := int(player.call("get_fire_request_count"))
                player.call("_begin_landing_movement_lock", 0.0, 0.0, false)
                _expect(bool(player.call("is_landing_movement_locked")), "Player should mark movement locked during the original landing recovery.")
                _expect(not bool(player.call("fire_wasp")), "Fire action should be rejected during the original landing recovery state.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests_before_landing_block, "Rejected landing-recovery fire should not increment accepted fire count.")
                _expect(int(inventory.call("get_ammo_count")) == 3, "Rejected landing-recovery fire should leave wasp ammo unchanged.")
                player.set("velocity", Vector3(0.0, 0.0, -5.2))
                player.set("rotation", Vector3.ZERO)
                Input.action_press("move_forward")
                Input.action_press("turn_right")
                player.call("_physics_process", minf(landing_lock_duration * 0.25, 1.0 / 60.0))
                Input.action_release("move_forward")
                Input.action_release("turn_right")
                var landing_locked_velocity := player.get("velocity") as Vector3
                var landing_locked_horizontal_speed := Vector3(landing_locked_velocity.x, 0.0, landing_locked_velocity.z).length()
                _expect(landing_locked_horizontal_speed < 5.2, "Landing recovery should temporarily damp Sammy's movement.")
                _expect(is_equal_approx((player as Node3D).rotation.y, 0.0), "Landing recovery should suppress turn input.")
                player.call("_update_landing_movement_lock", landing_lock_duration + 0.1)
                _expect(not bool(player.call("is_landing_movement_locked")), "Landing movement lock should release after the original FinJump recovery.")
                _expect(bool(player.call("fire_wasp")), "Fire action should be accepted when Sammy has wasp ammo.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests + 1, "Accepted fire should increment the accepted fire count.")
                _expect(bool(player.call("is_wasp_fire_locked")), "Accepted fire should lock Sammy in the original shooting state.")
                _expect(int(inventory.call("get_ammo_count")) == 3, "Accepted fire should defer ammo consumption until the wasp is spawned.")
                _expect(root.get_child_count() == children_before, "Accepted fire should defer wasp projectile creation until tirA completes.")
                _expect(not bool(player.call("fire_wasp")), "A second fire input during the original shooting state should be rejected quietly.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests + 1, "Rejected cooldown fire should not increment accepted fire count.")
                player.set("velocity", Vector3(0.0, 0.0, -5.2))
                player.set("rotation", Vector3.ZERO)
                Input.action_press("move_forward")
                Input.action_press("turn_right")
                player.call("_physics_process", minf(fire_spawn_delay * 0.25, 1.0 / 60.0))
                Input.action_release("move_forward")
                Input.action_release("turn_right")
                var locked_velocity := player.get("velocity") as Vector3
                var locked_horizontal_speed := Vector3(locked_velocity.x, 0.0, locked_velocity.z).length()
                _expect(locked_horizontal_speed < 5.2, "Accepted fire should temporarily damp Sammy's movement like PlayerEtat 2.")
                _expect(is_equal_approx((player as Node3D).rotation.y, 0.0), "Accepted fire should suppress turn input while Sammy is shooting.")
                if controller != null:
                    _expect(String(controller.call("get_current_action")) == "tirA", "Accepted fire should start Sammy's original tirA animation.")
                    var fire_animation_player := controller.get("animation_player") as AnimationPlayer
                    if fire_animation_player != null:
                        _expect(is_equal_approx(fire_animation_player.speed_scale, float(wasp_type.get("fire_animation_speed"))), "Type 2 fire should play tirA at the original 2.2 speed multiplier.")
                player.call("_update_wasp_fire_timing", fire_spawn_delay + 0.001)
                _expect(int(inventory.call("get_ammo_count")) == 2, "Wasp spawn should consume one ammo after the original tirA delay.")
                _expect(root.get_child_count() == children_before + 1, "Completing tirA should add a wasp projectile to the player's parent.")
                if audio != null and player_assets != null:
                    _expect(_audio_service_has_stream(audio, player_assets.load_asset("sfx.wasp") as AudioStream), "Accepted fire should play original Wasp_son.")
                var spawned_projectile := root.get_child(root.get_child_count() - 1)
                _expect(spawned_projectile.has_method("get_wasp_type"), "Firing should spawn a wasp projectile node.")
                if spawned_projectile.has_method("get_wasp_type"):
                    _expect(spawned_projectile.call("get_wasp_type") == wasp_type, "Spawned projectile should keep the active wasp type.")
                if player_assets != null and player_assets.has_method("load_wasp_skin_texture"):
                    var expected_skin := player_assets.call("load_wasp_skin_texture", int(wasp_type.get("skin_index"))) as Texture2D
                    _expect(expected_skin != null and _model_uses_texture(spawned_projectile, expected_skin), "Spawned wasp projectile should use the active type skin.")
                _expect(not bool(player.call("fire_wasp")), "Fire action should stay locked during the post-spawn recovery.")
                spawned_projectile.queue_free()
                await process_frame
                player.call("_update_wasp_fire_timing", fire_recovery + 0.1)
                _expect(not bool(player.call("is_wasp_fire_locked")), "Wasp fire lock should release after the original tirB recovery.")
                var children_before_second_fire := root.get_child_count()
                var fire_requests_before_second := int(player.call("get_fire_request_count"))
                _expect(bool(player.call("fire_wasp")), "Fire action should be accepted again after the wasp recovery cooldown.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests_before_second + 1, "Accepted post-cooldown fire should increment the fire count.")
                player.call("_update_wasp_fire_timing", fire_spawn_delay + fire_recovery + 0.2)
                _expect(int(inventory.call("get_ammo_count")) == 1, "Second spawned wasp should consume one more ammo.")
                _expect(root.get_child_count() == children_before_second_fire + 1, "Second post-cooldown fire should spawn another wasp projectile.")
                var second_spawned_projectile := root.get_child(root.get_child_count() - 1)
                if second_spawned_projectile.has_method("get_wasp_type"):
                    _expect(second_spawned_projectile.call("get_wasp_type") == wasp_type, "Second spawned projectile should keep the active wasp type.")
                second_spawned_projectile.queue_free()
                await process_frame
                var type_3: Resource = load(WASP_TYPE_3_PATH)
                inventory.call("add_ammo", type_3, 3)
                var children_before_multi_fire := root.get_child_count()
                var type_3_spawn_delay := float(player.call("_get_wasp_fire_spawn_delay_seconds", type_3))
                var type_3_interval := float(player.call("_get_wasp_multi_shot_interval_seconds", type_3))
                _expect(bool(player.call("fire_wasp")), "Type 3 fire should be accepted when Sammy has triple-shot ammo.")
                player.call("_update_wasp_fire_timing", type_3_spawn_delay + type_3_interval * 2.0 + 0.001)
                _expect(int(inventory.call("get_ammo_count")) == 0, "Type 3 should consume one ammo for each of the three WDL spread shots.")
                _expect(root.get_child_count() == children_before_multi_fire + 3, "Type 3 should spawn the original three spread wasps from one fire input.")
                var has_left_spread := false
                var has_center_spread := false
                var has_right_spread := false
                for child_index in range(children_before_multi_fire, root.get_child_count()):
                    var spread_projectile := root.get_child(child_index)
                    if spread_projectile.has_method("get_wasp_type"):
                        _expect(spread_projectile.call("get_wasp_type") == type_3, "Type 3 spread projectile should keep the active wasp type.")
                    if spread_projectile.has_method("get_velocity"):
                        var spread_velocity := spread_projectile.call("get_velocity") as Vector3
                        has_left_spread = has_left_spread or spread_velocity.x < -0.1
                        has_center_spread = has_center_spread or absf(spread_velocity.x) < 0.1
                        has_right_spread = has_right_spread or spread_velocity.x > 0.1
                _expect(has_left_spread and has_center_spread and has_right_spread, "Type 3 should use the original -5/0/+5 degree spread pattern.")
                for child_index in range(children_before_multi_fire, root.get_child_count()):
                    root.get_child(child_index).queue_free()
                await process_frame
                player.call("_update_wasp_fire_timing", fire_recovery + 0.1)
                _expect(not bool(player.call("is_wasp_fire_locked")), "Type 3 fire lock should release after the shared tirB recovery.")
                inventory.call("consume_ammo", 1)
                var ammo_after_drain := int(inventory.call("get_ammo_count"))
                var fire_requests_after_valid := int(player.call("get_fire_request_count"))
                _expect(not bool(player.call("fire_wasp")), "Fire action should be rejected after Sammy drains all wasp ammo.")
                _expect(int(inventory.call("get_ammo_count")) == ammo_after_drain, "Firing without ammo should leave the ammo count unchanged.")
                _expect(int(player.call("get_fire_request_count")) == fire_requests_after_valid, "Rejected drained-ammo fire should not increment accepted fire count.")
        var movement_config: Resource = player.get("movement_config")
        _expect(is_equal_approx(float(movement_config.get("boost_speed_multiplier")), 2.0), "Boost should expose the original acceleration control hook.")
        _expect(is_equal_approx(float(movement_config.get("boost_turn_multiplier")), 0.75), "Boost should reduce turn input like the original scripts.")
        _expect(is_equal_approx(float(movement_config.get("quick_turn_time_units_per_second")), 16.0), "Quick turn should use the original WDL time-unit scale.")
        _expect(is_equal_approx(float(movement_config.get("quick_turn_initial_speed_factor")), 0.25), "Quick turn should start with the original demi-tour speed factor.")
        _expect(is_equal_approx(float(movement_config.get("quick_turn_followup_speed_factor")), 0.4), "Quick turn should converge with the original demi-tour follow-up factor.")
        _expect(is_equal_approx(float(movement_config.get("quick_turn_stop_speed_degrees")), 2.0), "Quick turn should stop when the original demi-tour speed threshold is reached.")
        _expect(is_equal_approx(float(movement_config.get("quick_turn_animation_speed_multiplier")), 2.0), "Quick turn should double the base turn animation speed.")
        _expect(is_equal_approx(float(movement_config.get("boost_capacity_max")), 150.0), "Boost capacity should use the original panel width.")
        _expect(is_equal_approx(float(movement_config.get("boost_initial_capacity")), 0.0), "Player should start without stored boost capacity.")
        _expect(is_equal_approx(float(movement_config.get("boost_pickup_capacity")), 150.0), "Prototype boost pickup should fill one full boost meter.")
        _expect(is_equal_approx(float(movement_config.get("boost_consumption_per_second")), 16.0), "Boost consumption should mirror original ConsoBoost/time units.")
        _expect(is_equal_approx(float(movement_config.get("animation_blend_seconds")), 0.18), "Player animation blends should be slower than the initial scaffold blend.")
        _expect(is_equal_approx(float(movement_config.get("walk_stop_blend_seconds")), 0.35), "Stopping from walk should use the original-style slower walk-to-stand transition.")
        _expect(is_equal_approx(float(movement_config.get("walk_animation_speed_multiplier")), 1.75), "Gameplay walk animation should use the faster original in-game playback rate.")
        _expect(player.has_method("add_boost_capacity"), "Player controller should expose boost refill for pickups.")
        _expect(player.has_method("get_boost_capacity"), "Player controller should expose current boost capacity.")
        _expect(player.has_method("get_boost_capacity_max"), "Player controller should expose max boost capacity.")
        _expect(player.has_method("get_boost_capacity_ratio"), "Player controller should expose boost capacity ratio.")
        _expect(player.has_method("is_boosting"), "Player controller should expose active boost state.")
        if player.has_method("add_boost_capacity") and player.has_method("get_boost_capacity") and player.has_method("get_boost_capacity_max") and player.has_method("get_boost_capacity_ratio") and player.has_method("is_boosting"):
            var boost_capacity_max := float(player.call("get_boost_capacity_max"))
            _expect(is_equal_approx(float(player.call("get_boost_capacity")), 0.0), "Player should start with an empty boost meter.")
            _expect(is_equal_approx(float(player.call("get_boost_capacity_ratio")), 0.0), "Empty boost meter ratio should be zero.")
            _expect(is_equal_approx(float(player.call("add_boost_capacity", boost_capacity_max)), boost_capacity_max), "Boost refill should report the amount added.")
            _expect(is_equal_approx(float(player.call("get_boost_capacity")), boost_capacity_max), "Boost refill should fill the meter.")
            _expect(is_equal_approx(float(player.call("add_boost_capacity", boost_capacity_max)), 0.0), "Boost refill should clamp at the max meter.")
            _expect(is_equal_approx(float(player.call("get_boost_capacity_ratio")), 1.0), "Full boost meter ratio should be one.")
            player.call("_update_boost_state_from_input", 0.25, 0.0, true)
            _expect(not bool(player.call("is_boosting")), "Boost should not activate without forward movement.")
            _expect(is_equal_approx(float(player.call("get_boost_capacity")), boost_capacity_max), "Boost should not consume capacity without forward movement.")
            var boost_before_drain := float(player.call("get_boost_capacity"))
            player.call("_update_boost_state_from_input", 0.25, 1.0, true)
            _expect(bool(player.call("is_boosting")), "Holding boost while moving forward should activate stored boost.")
            _expect(float(player.call("get_boost_capacity")) < boost_before_drain, "Active boost should consume stored capacity.")
            var boost_after_release := float(player.call("get_boost_capacity"))
            player.call("_update_boost_state_from_input", 0.25, 1.0, false)
            _expect(not bool(player.call("is_boosting")), "Releasing Shift should stop active boost.")
            _expect(is_equal_approx(float(player.call("get_boost_capacity")), boost_after_release), "Released boost should stop consuming capacity.")
            player.call("add_boost_capacity", boost_capacity_max)
            movement_config.set("boost_consumption_per_second", boost_capacity_max * 120.0)
            player.call("_update_boost_state_from_input", 1.0, 1.0, true)
            player.call("_update_boost_state_from_input", 1.0, 1.0, true)
            _expect(is_equal_approx(float(player.call("get_boost_capacity")), 0.0), "Boost should clamp to zero after depletion.")
            _expect(not bool(player.call("is_boosting")), "Boost should stop once capacity is depleted.")
        _expect(player.has_method("get_walk_animation_speed_for_horizontal_speed"), "Player controller should expose gameplay walk animation speed for validation.")
        if player.has_method("get_walk_animation_speed_for_horizontal_speed"):
            var walk_speed := float(movement_config.get("walk_speed"))
            var walk_animation_speed := float(player.call("get_walk_animation_speed_for_horizontal_speed", walk_speed))
            var boost_animation_speed := float(player.call("get_walk_animation_speed_for_horizontal_speed", walk_speed * float(movement_config.get("boost_speed_multiplier"))))
            _expect(is_equal_approx(walk_animation_speed, 1.75), "Gameplay walking should play the walk cycle faster than menu/cinematic playback.")
            _expect(is_equal_approx(boost_animation_speed, 3.5), "Boost movement should also advance the walk cycle proportionally to horizontal speed.")
        _expect(player.has_method("get_animation_blend_seconds_for_transition"), "Player controller should expose animation transition blend timing for validation.")
        if player.has_method("get_animation_blend_seconds_for_transition"):
            _expect(is_equal_approx(float(player.call("get_animation_blend_seconds_for_transition", &"stand", &"walkB")), 0.18), "Stand-to-walk should use the slower default player blend.")
            _expect(is_equal_approx(float(player.call("get_animation_blend_seconds_for_transition", &"walkB", &"stand")), 0.35), "Walk-to-stand should use the slower original-style stop transition.")
            _expect(is_equal_approx(float(player.call("get_animation_blend_seconds_for_transition", &"walkB", &"walkB")), 0.0), "Same-action speed changes should not restart or reblend the walk cycle.")
    player.queue_free()
    await process_frame


func _test_prototype_world() -> void:
    var prototype_scene: PackedScene = load(PROTOTYPE_SCENE_PATH)
    var world: Node = prototype_scene.instantiate()
    _expect(world.get_node_or_null("PrototypeFloor") != null, "Prototype floor should be serialized in the scene.")
    _expect(world.get_node_or_null("Sun") != null, "Prototype lighting should be serialized in the scene.")
    _expect(world.get_node_or_null("Player") != null, "Prototype player should be editor-instanced.")
    _expect(world.get_node_or_null("PrototypeCamera") != null, "Prototype camera should be editor-instanced.")
    _expect(world.get_node_or_null("BoostPickup") != null, "Prototype boost pickup should be editor-instanced.")
    _expect(world.get_node_or_null("DebugOverlay") != null, "Prototype debug overlay should be editor-instanced.")
    var floor := world.get_node_or_null("PrototypeFloor") as StaticBody3D
    _expect(floor != null, "Prototype floor should be a StaticBody3D.")
    if floor != null:
        _expect(floor.collision_layer == WORLD_LAYER, "Prototype floor should live on the world collision layer.")
        _expect(floor.collision_mask == CHARACTER_LAYER, "Prototype floor should collide with solid characters.")
    var props := world.get_node_or_null("Props")
    _expect(props != null, "Prototype scene should expose a designer-editable Props container.")
    for prop_path in ["Props/model_cactus1", "Props/model_sky3"]:
        _expect(world.get_node_or_null(prop_path) != null, "Prototype prop should be editor-instanced: %s" % prop_path)
    var cactus := world.get_node_or_null("Props/model_cactus1") as StaticBody3D
    _expect(cactus != null, "Prototype cactus should be a StaticBody3D solid prop.")
    if cactus != null:
        _expect(cactus.collision_layer == WORLD_LAYER, "Prototype cactus should live on the world collision layer.")
        _expect(cactus.collision_mask == CHARACTER_LAYER, "Prototype cactus should collide with solid characters.")
        _expect(cactus.get_node_or_null("CollisionShape3D") != null, "Prototype cactus should expose a trunk collision shape.")
    var enemies := world.get_node_or_null("Enemies")
    _expect(enemies != null, "Prototype scene should expose a designer-editable Enemies container.")
    for enemy_path in ["Enemies/model_rasta_animated", "Enemies/model_punk_animated"]:
        var enemy := world.get_node_or_null(enemy_path) as CharacterBody3D
        _expect(enemy != null, "Prototype enemy should be editor-instanced as a CharacterBody3D: %s" % enemy_path)
        if enemy != null:
            _expect(enemy.collision_layer == CHARACTER_LAYER, "Prototype enemy should live on the character collision layer: %s" % enemy_path)
            _expect(enemy.collision_mask == WORLD_AND_CHARACTER_MASK, "Prototype enemy should collide with world and other solid characters: %s" % enemy_path)
    root.add_child(world)
    await process_frame
    await process_frame
    _expect(world.get_node_or_null("Player") != null, "Prototype world is missing its editor-instanced player.")
    var debug_overlay := world.get_node_or_null("DebugOverlay")
    var debug_label: Label = null
    if debug_overlay != null:
        debug_overlay.call("_physics_process", 0.0)
        if debug_overlay.get_child_count() > 0:
            debug_label = debug_overlay.get_child(0) as Label
        _expect(debug_label != null and debug_label.text.contains("Wasps: 0"), "Prototype debug overlay should show zero wasps before pickup collection.")
    var camera := world.get_node_or_null("PrototypeCamera")
    _expect(camera != null, "Prototype world is missing its editor-instanced camera.")
    if camera != null:
        _expect(is_equal_approx(camera.follow_distance, 4.25), "Prototype camera should use original-informed close follow distance.")
        _expect(is_equal_approx(camera.fov, 60.0), "Prototype camera should match original CameraArcVoulu.")
        var camera_position: Vector3 = camera.global_position
        camera.call("cycle_camera_mode")
        _expect(not camera.global_position.is_equal_approx(camera_position), "Camera change should cycle the prototype camera offset.")
    _expect(world.get_node_or_null("Sun") != null, "Prototype world is missing editor-authored lighting.")
    _expect(world.has_meta("wmb_manifest_counts"), "Prototype world did not read WMB manifest metadata.")
    var assets := root.get_node_or_null("Assets")
    if assets != null:
        for node_name in ["model_rasta_animated", "model_punk_animated"]:
            var model := world.get_node_or_null("Enemies/%s" % node_name) as Node3D
            _expect(model != null, "Prototype world should contain grounded character model: %s" % node_name)
            if model != null:
                var bounds: AABB = assets.get_model_global_bounds(model)
                _expect(absf(bounds.position.y) < 0.01, "Prototype character model should be grounded: %s" % node_name)
        for model_path in ["Enemies/model_rasta_animated", "Enemies/model_punk_animated", "Props/model_cactus1"]:
            var model := world.get_node_or_null(model_path) as Node3D
            _expect(model != null, "Prototype world should contain animated catalog model: %s" % model_path)
            if model != null:
                var controller := model.get_node_or_null("ModelAnimationController")
                _expect(controller != null, "Prototype model should have generated animation controller: %s" % model_path)
                if controller != null:
                    _expect(bool(controller.call("has_action", "stand")), "Prototype model should expose stand animation: %s" % model_path)
                    _expect(String(controller.call("get_current_action")) == "stand", "Prototype model should autoplay stand animation: %s" % model_path)
        var boost_pickup := world.get_node_or_null("BoostPickup") as Area3D
        _expect(boost_pickup != null, "Prototype world should spawn the boost pickup as an Area3D.")
        if boost_pickup != null:
            _expect(boost_pickup.collision_layer == PICKUP_SENSOR_LAYER, "Boost pickup should live on the pickup sensor collision layer.")
            _expect(boost_pickup.collision_mask == CHARACTER_LAYER, "Boost pickup should monitor solid characters without blocking them.")
            _expect(boost_pickup.has_method("collect"), "Boost pickup should expose a collection hook for tests/importers.")
            _expect(boost_pickup.has_method("was_collected"), "Boost pickup should expose collected state.")
            _expect(is_equal_approx(float(boost_pickup.call("get_boost_amount")), 150.0), "Prototype boost pickup should fill the meter.")
            _expect(String(boost_pickup.get("collect_sound_asset_id")) == "sfx.boost_pickup", "Boost pickup should use the original chimes2 sound.")
            _expect(is_equal_approx(float(boost_pickup.get("visual_ground_clearance")), 0.035), "Boost pickup should keep the visual model just above the floor.")
            _expect(is_equal_approx(float(boost_pickup.get("boost_animation_speed")), 2.0), "Boost pickup should use the faster original InitBoost cycle rate.")
            var boost_model := boost_pickup.get_node_or_null("model_boost") as Node3D
            _expect(boost_model != null, "Boost pickup should spawn the animated boost model.")
            if boost_model != null:
                var boost_bounds: AABB = assets.get_model_global_bounds(boost_model)
                _expect(boost_bounds.position.y >= 0.025, "Boost pickup visual should not intersect the floor.")
                var boost_controller := boost_model.get_node_or_null("ModelAnimationController")
                _expect(boost_controller != null, "Boost pickup model should have generated animation controller.")
                if boost_controller != null:
                    _expect(bool(boost_controller.call("has_action", "stand")), "Boost pickup model should expose stand animation.")
                    _expect(String(boost_controller.call("get_current_action")) == "stand", "Boost pickup model should autoplay stand animation.")
                    var boost_animation_player := boost_controller.get("animation_player") as AnimationPlayer
                    if boost_animation_player != null:
                        _expect(boost_animation_player.speed_scale < 0.0, "Boost pickup stand animation should play in the original rotation direction.")
                        _expect(is_equal_approx(boost_animation_player.speed_scale, -float(boost_pickup.get("boost_animation_speed"))), "Boost pickup stand animation should use the original faster cycle speed.")
            var boost_effect := boost_pickup.get_node_or_null("BoostPickupEffect")
            _expect(boost_effect != null, "Boost pickup should spawn the original ambient boost particle effect.")
            if boost_effect != null:
                _expect(bool(boost_effect.call("is_emitting_effect")), "Boost pickup particle effect should emit while the pickup is active.")
                _expect(int(boost_effect.call("get_anchor_count")) == 2, "Boost pickup particle effect should use the two original vertex emitters.")
                _expect(bool(boost_effect.call("follows_model_vertices")), "Boost pickup particle effect should follow the animated model vertices.")
                _expect((boost_effect.call("get_tracked_vertex_indices") as PackedInt32Array) == PackedInt32Array([3, 11]), "Boost pickup particle effect should track original ent_vertex 3 and 11.")
                _expect((boost_effect.call("get_exported_vertex_indices") as PackedInt32Array) == PackedInt32Array([2, 38]), "Boost pickup particle effect should map WDL vertices onto the duplicated exported mesh vertices.")
                _expect(int(boost_effect.call("get_emitter_count")) == 2, "Boost pickup particle effect should create one particle emitter per original vertex.")
                _expect(int(boost_effect.call("get_particle_amount_per_emitter")) >= 10, "Boost pickup particle emitters should keep a denser original-style stream alive.")
                _expect((boost_effect.call("get_particle_quad_size") as Vector2).is_equal_approx(Vector2(0.1, 0.1)), "Boost pickup particles should use smaller original-style star sprites.")
                var boost_scale_samples := boost_effect.call("get_particle_scale_curve_samples") as PackedFloat32Array
                _expect(boost_scale_samples.size() == 3, "Boost pickup particle scale curve should expose start, midpoint, and end samples.")
                if boost_scale_samples.size() == 3:
                    _expect(is_equal_approx(boost_scale_samples[0], 1.0), "Boost pickup particles should start at full scale.")
                    _expect(is_equal_approx(boost_scale_samples[1], 0.62), "Boost pickup particles should shrink more gradually during their lifetime.")
                    _expect(is_equal_approx(boost_scale_samples[2], 0.14), "Boost pickup particles should end near the original particle kill-size ratio.")
                    _expect(float(boost_effect.call("get_particle_scale_at_lifetime_ratio", 0.0)) > float(boost_effect.call("get_particle_scale_at_lifetime_ratio", 0.5)), "Boost pickup particle scale should decrease by mid-life.")
                    _expect(float(boost_effect.call("get_particle_scale_at_lifetime_ratio", 0.5)) > float(boost_effect.call("get_particle_scale_at_lifetime_ratio", 1.0)), "Boost pickup particle scale should keep decreasing until death.")
                _expect(int(boost_effect.call("restart_emitters")) == 2, "Boost pickup particle emitters should be restartable for importer/test validation.")
                _expect(int(boost_effect.call("get_particle_capacity")) == 24, "Boost pickup particle effect should configure GPU particle capacity for both emitters.")
                var boost_emitter := boost_effect.get_node_or_null("BoostEmitter0") as GPUParticles3D
                _expect(boost_emitter != null, "Boost pickup particle effect should expose a vertex-following GPUParticles3D emitter node.")
                if boost_emitter != null:
                    _expect(boost_emitter.emitting, "Boost pickup GPU particle emitter should be active while the pickup is active.")
                    _expect(boost_emitter.amount == int(boost_effect.call("get_particle_amount_per_emitter")), "Boost pickup GPU emitter should preserve the original-style particle count.")
                    _expect(is_equal_approx(boost_emitter.lifetime, 0.75), "Boost pickup GPU emitter should preserve the original-style particle lifetime.")
                    _expect(is_equal_approx(boost_emitter.preprocess, 0.75), "Boost pickup GPU emitter should prewarm a full particle lifetime.")
                    _expect(not boost_emitter.local_coords, "Boost pickup GPU particles should remain in world space after emission.")
                    _expect(boost_emitter.draw_passes == 1, "Boost pickup GPU emitter should use one star-sprite draw pass.")
                    var draw_mesh := boost_emitter.get_draw_pass_mesh(0) as QuadMesh
                    _expect(draw_mesh != null, "Boost pickup GPU emitter should draw the original star sprite quad.")
                    if draw_mesh != null:
                        _expect(draw_mesh.size.is_equal_approx(Vector2(0.1, 0.1)), "Boost pickup GPU draw pass should keep the smaller original-style star sprite size.")
                        var particle_material := draw_mesh.material as StandardMaterial3D
                        _expect(particle_material != null, "Boost pickup GPU draw pass should use a 3D particle material.")
                        if particle_material != null:
                            _expect(particle_material.albedo_texture == assets.load_asset("texture.particle.small_star_1a"), "Boost pickup GPU particles should use the original boost star texture.")
                            _expect(particle_material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Boost pickup GPU particles should use additive blending.")
                            _expect(particle_material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "Boost pickup GPU particles should billboard like the previous sparkle quads.")
                            _expect(particle_material.billboard_keep_scale, "Boost pickup GPU billboard particles should preserve particle scale-over-lifetime.")
                            _expect(particle_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Boost pickup GPU particles should stay unshaded.")
                    var process_material := boost_emitter.process_material as ParticleProcessMaterial
                    _expect(process_material != null, "Boost pickup GPU emitter should use a ParticleProcessMaterial.")
                    if process_material != null:
                        _expect(process_material.direction.is_equal_approx(Vector3.UP), "Boost pickup GPU particles should drift upward from the tracked vertices.")
                        _expect(process_material.gravity.is_equal_approx(Vector3.ZERO), "Boost pickup GPU particles should not fall under world gravity.")
                        _expect(is_equal_approx(process_material.initial_velocity_min, 0.55), "Boost pickup GPU particles should preserve the lower upward velocity.")
                        _expect(is_equal_approx(process_material.initial_velocity_max, 1.1), "Boost pickup GPU particles should preserve the upper upward velocity.")
                        var scale_curve_texture := process_material.scale_curve as CurveTexture
                        _expect(scale_curve_texture != null and scale_curve_texture.curve != null, "Boost pickup GPU particles should use a scale-over-lifetime curve.")
                        if scale_curve_texture != null and scale_curve_texture.curve != null:
                            _expect(is_equal_approx(scale_curve_texture.curve.sample(0.0), 1.0), "Boost pickup GPU particles should start at full scale.")
                            _expect(absf(scale_curve_texture.curve.sample(0.5) - 0.62) < 0.01, "Boost pickup GPU particles should shrink gradually during their lifetime.")
                            _expect(absf(scale_curve_texture.curve.sample(1.0) - 0.14) < 0.01, "Boost pickup GPU particles should end near the original particle kill-size ratio.")
                    var emitter_position := boost_effect.call("get_emitter_local_position", 0) as Vector3
                    _expect(boost_emitter.position.is_equal_approx(emitter_position), "Boost pickup emitter node should stay on the tracked model vertex.")
            var player := world.get_node_or_null("Player")
            if player != null and player.has_method("get_boost_capacity") and player.has_method("get_boost_capacity_max"):
                _expect(is_equal_approx(float(player.call("get_boost_capacity")), 0.0), "Prototype player should start with empty boost before pickup collection.")
                boost_pickup.set("collect_sound_asset_id", "")
                _expect(bool(boost_pickup.call("collect", player)), "Boost pickup should collect when given the player.")
                _expect(is_equal_approx(float(player.call("get_boost_capacity")), float(player.call("get_boost_capacity_max"))), "Boost pickup should fill the player meter.")
                _expect(bool(boost_pickup.call("was_collected")), "Boost pickup should mark itself collected.")
                if boost_effect != null:
                    _expect(not bool(boost_effect.call("is_emitting_effect")), "Boost pickup particle effect should stop after collection.")
                    var stopped_emitter := boost_effect.get_node_or_null("BoostEmitter0") as GPUParticles3D
                    if stopped_emitter != null:
                        _expect(not stopped_emitter.emitting, "Boost pickup GPU particle emitters should stop after collection.")
                _expect(not boost_pickup.visible, "Boost pickup should hide after collection.")
        var wasp_pickup := world.get_node_or_null("WaspPickup") as Area3D
        _expect(wasp_pickup != null, "Prototype world should spawn the wasp pickup as an Area3D.")
        if wasp_pickup != null:
            _expect(wasp_pickup.collision_layer == PICKUP_SENSOR_LAYER, "Wasp pickup should live on the pickup sensor collision layer.")
            _expect(wasp_pickup.collision_mask == CHARACTER_LAYER, "Wasp pickup should monitor solid characters without blocking them.")
            _expect(wasp_pickup.has_method("collect"), "Wasp pickup should expose a collection hook for tests/importers.")
            _expect(wasp_pickup.has_method("was_collected"), "Wasp pickup should expose collected state.")
            _expect(wasp_pickup.has_method("get_wasp_type"), "Wasp pickup should expose its configured wasp type.")
            _expect(int(wasp_pickup.call("get_ammo_amount")) == 20, "Prototype wasp pickup should grant the original-style ammo bundle.")
            _expect(String(wasp_pickup.get("collect_sound_asset_id")) == "sfx.takewasp", "Wasp pickup should use the original TakeWasp sound.")
            var pickup_wasp_type: Resource = wasp_pickup.call("get_wasp_type")
            _expect(pickup_wasp_type == load(WASP_TYPE_2_PATH), "Prototype wasp pickup should be configured for type 2.")
            var wasp_model := wasp_pickup.get_node_or_null("WaspPickupVisual") as Node3D
            _expect(wasp_model != null, "Wasp pickup should spawn the original wasp model visual.")
            if wasp_model != null and pickup_wasp_type != null and assets != null and assets.has_method("load_wasp_skin_texture"):
                var expected_pickup_skin := assets.call("load_wasp_skin_texture", int(pickup_wasp_type.get("skin_index"))) as Texture2D
                _expect(expected_pickup_skin != null and _model_uses_texture(wasp_model, expected_pickup_skin), "Wasp pickup visual should use the configured type skin.")
                var pickup_controller := wasp_pickup.call("get_animation_controller") as Node
                _expect(pickup_controller != null, "Wasp pickup should attach a generated animation controller.")
                if pickup_controller != null:
                    _expect(bool(pickup_controller.call("has_action", "stand")), "Wasp pickup animation controller should expose stand.")
                    _expect(String(pickup_controller.call("get_current_action")) == "stand", "Wasp pickup should play the original stand cycle.")
                var pickup_rotation_before := wasp_model.rotation.y
                wasp_pickup.call("_process", 0.5)
                _expect(absf(wasp_model.rotation.y - pickup_rotation_before) > 0.01, "Wasp pickup should rotate at the original idle pan rate.")
            var wasp_pickup_nodes := [
                "",
                "WaspPickupType1",
                "WaspPickup",
                "WaspPickupType3",
                "WaspPickupType4",
                "WaspPickupType5",
                "WaspPickupType6",
                "WaspPickupType7"
            ]
            for type_id in range(1, wasp_pickup_nodes.size()):
                var typed_wasp_pickup := world.get_node_or_null(wasp_pickup_nodes[type_id]) as Area3D
                _expect(typed_wasp_pickup != null, "Prototype world should expose wasp type %d pickup for playtesting." % type_id)
                if typed_wasp_pickup == null:
                    continue
                _expect(typed_wasp_pickup.collision_layer == PICKUP_SENSOR_LAYER, "Wasp type %d pickup should live on the pickup sensor collision layer." % type_id)
                _expect(typed_wasp_pickup.collision_mask == CHARACTER_LAYER, "Wasp type %d pickup should monitor solid characters without blocking them." % type_id)
                _expect(int(typed_wasp_pickup.call("get_ammo_amount")) == 20, "Wasp type %d prototype pickup should grant the original-style ammo bundle." % type_id)
                var typed_wasp_type: Resource = typed_wasp_pickup.call("get_wasp_type")
                _expect(typed_wasp_type == load(WASP_TYPE_PATHS[type_id]), "Prototype wasp pickup should be configured for type %d." % type_id)
                var typed_wasp_model := typed_wasp_pickup.get_node_or_null("WaspPickupVisual") as Node3D
                _expect(typed_wasp_model != null, "Wasp type %d pickup should spawn the original wasp model visual." % type_id)
                if typed_wasp_model != null and typed_wasp_type != null and assets != null and assets.has_method("load_wasp_skin_texture"):
                    var typed_expected_skin := assets.call("load_wasp_skin_texture", int(typed_wasp_type.get("skin_index"))) as Texture2D
                    _expect(typed_expected_skin != null and _model_uses_texture(typed_wasp_model, typed_expected_skin), "Wasp type %d pickup visual should use the configured type skin." % type_id)
                    var typed_wasp_controller := typed_wasp_pickup.call("get_animation_controller") as Node
                    _expect(typed_wasp_controller != null, "Wasp type %d pickup should attach a generated animation controller." % type_id)
                    if typed_wasp_controller != null:
                        _expect(String(typed_wasp_controller.call("get_current_action")) == "stand", "Wasp type %d pickup should play the original stand cycle." % type_id)
            var player_for_wasp := world.get_node_or_null("Player")
            if player_for_wasp != null and player_for_wasp.has_method("get_wasp_inventory"):
                var inventory: Node = player_for_wasp.call("get_wasp_inventory")
                _expect(inventory != null, "Prototype player should expose a wasp inventory for pickups.")
                if inventory != null:
                    _expect(int(inventory.call("get_ammo_count")) == 0, "Prototype player should start without wasp ammo before pickup collection.")
                    wasp_pickup.set("collect_sound_asset_id", "")
                    _expect(bool(wasp_pickup.call("collect", player_for_wasp)), "Wasp pickup should collect when given the player.")
                    _expect(inventory.call("get_current_type") == pickup_wasp_type, "Wasp pickup should set the active wasp type.")
                    _expect(int(inventory.call("get_ammo_count")) == int(wasp_pickup.call("get_ammo_amount")), "Wasp pickup should add its ammo amount to the inventory.")
                    if debug_overlay != null and debug_label != null:
                        debug_overlay.call("_physics_process", 0.0)
                        _expect(debug_label.text.contains("Wasps: %d" % int(wasp_pickup.call("get_ammo_amount"))), "Prototype debug overlay should show the current wasp ammo count.")
                    _expect(bool(wasp_pickup.call("was_collected")), "Wasp pickup should mark itself collected.")
                    _expect(not wasp_pickup.visible, "Wasp pickup should hide after collection.")
                    await process_frame
                    _expect(not wasp_pickup.monitoring, "Wasp pickup should stop monitoring after collection.")
                    _expect(not wasp_pickup.monitorable, "Wasp pickup should stop being monitorable after collection.")
    await _expect_solid_collision_contacts(world)
    await _expect_enemy_gravity(world)
    var audio := root.get_node_or_null("Audio")
    if audio != null:
        audio.stop_music()
    world.queue_free()
    await process_frame


func _expect_solid_collision_contacts(world: Node) -> void:
    var player := world.get_node_or_null("Player") as CharacterBody3D
    var rasta := world.get_node_or_null("Enemies/model_rasta_animated") as CharacterBody3D
    var cactus := world.get_node_or_null("Props/model_cactus1") as StaticBody3D
    var boost_pickup := world.get_node_or_null("BoostPickup") as Area3D

    _expect(player != null, "Prototype collision probe needs the player body.")
    if player == null:
        return

    if rasta != null:
        player.global_position = rasta.global_position + Vector3(0.0, 0.0, 1.35)
        await physics_frame
        _expect(player.test_move(player.global_transform, Vector3(0.0, 0.0, -1.0)), "Player should be blocked by solid enemy character bodies.")

    if cactus != null:
        player.global_position = cactus.global_position + Vector3(0.0, 0.0, 1.15)
        await physics_frame
        _expect(player.test_move(player.global_transform, Vector3(0.0, 0.0, -0.9)), "Player should be blocked by solid prototype props.")

    if boost_pickup != null:
        _expect(boost_pickup is Area3D, "Boost pickup should stay an Area3D sensor.")
        _expect(boost_pickup.get_class() == "Area3D", "Boost pickup should not become a blocking physics body.")


func _expect_enemy_gravity(world: Node) -> void:
    for enemy_path in ["Enemies/model_rasta_animated", "Enemies/model_punk_animated"]:
        var enemy := world.get_node_or_null(enemy_path) as CharacterBody3D
        _expect(enemy != null, "Prototype enemy should be a gravity-aware CharacterBody3D: %s" % enemy_path)
        if enemy == null:
            continue

        _expect(enemy.is_in_group("enemy"), "Prototype enemy should be in the enemy group: %s" % enemy_path)
        _expect(is_equal_approx(float(enemy.get("original_gravity_velocity")), -4.0), "Enemy gravity should preserve original graviteEnnemy: %s" % enemy_path)
        _expect(is_equal_approx(float(enemy.get("original_gravity_acceleration")), 3.0), "Enemy gravity should preserve original AccgraviteEnnemy: %s" % enemy_path)
        _expect(enemy.has_method("get_initial_fall_velocity"), "Enemy should expose converted initial fall velocity: %s" % enemy_path)
        _expect(enemy.has_method("get_gravity_acceleration"), "Enemy should expose converted gravity acceleration: %s" % enemy_path)
        if enemy.has_method("get_initial_fall_velocity") and enemy.has_method("get_gravity_acceleration"):
            _expect(float(enemy.call("get_initial_fall_velocity")) < 0.0, "Enemy initial fall velocity should move downward in Godot Y-up space: %s" % enemy_path)
            _expect(float(enemy.call("get_gravity_acceleration")) > 0.0, "Enemy gravity acceleration should have a positive downward magnitude: %s" % enemy_path)

        var raised_y := enemy.global_position.y + 1.0
        enemy.global_position.y = raised_y
        if enemy.has_method("reset_vertical_motion"):
            enemy.call("reset_vertical_motion")
        await physics_frame
        await physics_frame
        await physics_frame
        _expect(enemy.global_position.y < raised_y, "Enemy should fall under original-style gravity when raised above the floor: %s" % enemy_path)


func _model_uses_texture(node: Node, texture: Texture2D) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            if material != null and material.albedo_texture == texture:
                return true

    for child in node.get_children():
        if _model_uses_texture(child, texture):
            return true
    return false


func _model_surface_with_texture_uses_shading_mode(node: Node, texture: Texture2D, expected_shading_mode: int) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            if material != null and material.albedo_texture == texture and material.shading_mode == expected_shading_mode:
                return true

    for child in node.get_children():
        if _model_surface_with_texture_uses_shading_mode(child, texture, expected_shading_mode):
            return true
    return false


func _model_uses_transparency_mode(node: Node, transparency_mode: int) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
            if material != null and material.transparency == transparency_mode:
                return true

    for child in node.get_children():
        if _model_uses_transparency_mode(child, transparency_mode):
            return true
    return false


func _model_uses_texture_filter(node: Node, expected_texture_filter: int) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
            if material != null and material.texture_filter == expected_texture_filter:
                return true

    for child in node.get_children():
        if _model_uses_texture_filter(child, expected_texture_filter):
            return true
    return false


func _model_uses_alpha_scissor_threshold(node: Node, expected_threshold: float) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
            if material != null and is_equal_approx(material.alpha_scissor_threshold, expected_threshold):
                return true

    for child in node.get_children():
        if _model_uses_alpha_scissor_threshold(child, expected_threshold):
            return true
    return false


func _model_materials_use_cull_mode(node: Node, expected_cull_mode: int) -> bool:
    var found_material := false
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
            if material == null:
                continue
            found_material = true
            if material.cull_mode != expected_cull_mode:
                return false

    for child in node.get_children():
        var child_result := _model_materials_use_cull_mode(child, expected_cull_mode)
        if child_result:
            found_material = true
        elif _model_has_base_material(child):
            return false
    return found_material


func _model_blend_shape_value(node: Node, shape_name: String) -> float:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null:
        var shape_index := mesh_instance.find_blend_shape_by_name(shape_name)
        if shape_index >= 0:
            return mesh_instance.get_blend_shape_value(shape_index)

    for child in node.get_children():
        var value := _model_blend_shape_value(child, shape_name)
        if value >= 0.0:
            return value
    return -1.0


func _model_has_base_material(node: Node) -> bool:
    var mesh_instance := node as MeshInstance3D
    if mesh_instance != null and mesh_instance.mesh != null:
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            if mesh_instance.get_active_material(surface_index) is BaseMaterial3D:
                return true

    for child in node.get_children():
        if _model_has_base_material(child):
            return true
    return false


func _audio_service_has_stream(audio: Node, stream: AudioStream) -> bool:
    if stream == null:
        return false
    for child in audio.get_children():
        var player := child as AudioStreamPlayer
        if player != null and player.stream == stream:
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)


func _action_has_key(action: StringName, keycode: int, physical_keycode: int) -> bool:
    for event in InputMap.action_get_events(action):
        var key_event := event as InputEventKey
        if key_event == null:
            continue
        if keycode != KEY_NONE and key_event.keycode == keycode:
            return true
        if physical_keycode != KEY_NONE and key_event.physical_keycode == physical_keycode:
            return true
    return false


func _action_has_joy_button(action: StringName, button_index: int) -> bool:
    for event in InputMap.action_get_events(action):
        var joy_event := event as InputEventJoypadButton
        if joy_event != null and joy_event.button_index == button_index:
            return true
    return false


func _action_has_joy_motion(action: StringName, axis: int, axis_value: float) -> bool:
    for event in InputMap.action_get_events(action):
        var joy_event := event as InputEventJoypadMotion
        if joy_event != null and joy_event.axis == axis and is_equal_approx(joy_event.axis_value, axis_value):
            return true
    return false


func _action_has_mouse_button(action: StringName, button_index: int) -> bool:
    for event in InputMap.action_get_events(action):
        var mouse_event := event as InputEventMouseButton
        if mouse_event != null and mouse_event.button_index == button_index:
            return true
    return false
