extends SceneTree

const ASSETS_SCRIPT_PATH := "res://src/core/assets.gd"
const WMB_MANIFEST_SCRIPT_PATH := "res://src/levels/wmb_manifest.gd"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"

var _failures: Array[String] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var assets := _ensure_assets_service()
    await process_frame

    _test_input_actions()
    _test_display_settings()
    _test_asset_catalog(assets)
    _test_model_skin_alpha()
    _test_wmb_manifest()
    await _test_player_scene()
    ProjectSettings.set_setting("sammy/test/skip_music", true)
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
    for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "interact", "camera_reset", "debug_toggle"]:
        _expect(InputMap.has_action(action), "Missing input action: %s" % action)


func _test_display_settings() -> void:
    _expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280, "Game viewport width should be 1280.")
    _expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 960, "Game viewport height should be 960.")
    _expect(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport", "Game viewport should scale to the window.")
    _expect(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep", "Game viewport should preserve its aspect ratio.")


func _test_asset_catalog(assets: Node) -> void:
    _expect(assets.has_asset("model.sammy.animated"), "Asset catalog is missing Sammy animated model.")
    _expect(assets.has_asset("metadata.wmb_manifest"), "Asset catalog is missing WMB manifest metadata.")
    var missing: Array[String] = assets.verify_required_assets()
    _expect(missing.is_empty(), "Missing catalog files: %s" % [", ".join(missing)])
    _expect(assets.load_asset("model.sammy.animated") != null, "Unable to load Sammy animated model resource.")
    _expect(assets.load_asset("model.rasta.animated") != null, "Unable to load copied rasta model resource.")
    _expect(assets.load_asset("model.punk.animated") != null, "Unable to load copied punk model resource.")
    _expect(assets.get_model_scale("model.sammy.animated").is_equal_approx(Vector3(0.08, 0.08, 0.08)), "Sammy model scale should include original WDL scale 8.")
    _expect(assets.get_model_scale("model.rasta.animated").is_equal_approx(Vector3(0.01, 0.01, 0.01)), "Rasta model should use default Acknex entity scale.")
    _expect(assets.has_asset("music.sammy01"), "Asset catalog is missing copied music resource.")
    _expect(assets.load_asset("sfx.collect") != null, "Unable to load copied sound-effect resource.")


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


func _text_file_lacks(path: String, needle: String) -> bool:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    return not file.get_as_text().contains(needle)


func _test_player_scene() -> void:
    var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
    var player: Node = player_scene.instantiate()
    root.add_child(player)
    await process_frame
    _expect(player is CharacterBody3D, "Player scene root must be CharacterBody3D.")
    _expect(player.get_node_or_null("CollisionShape3D") != null, "Player scene is missing collision shape.")
    _expect(player.get_node_or_null("VisualPivot") != null, "Player scene is missing visual pivot.")
    player.queue_free()
    await process_frame


func _test_prototype_world() -> void:
    var prototype_scene: PackedScene = load(PROTOTYPE_SCENE_PATH)
    var world: Node = prototype_scene.instantiate()
    root.add_child(world)
    await process_frame
    await process_frame
    _expect(world.get_node_or_null("Player") != null, "Prototype world did not spawn player.")
    var camera := world.get_node_or_null("PrototypeCamera")
    _expect(camera != null, "Prototype world did not spawn camera.")
    if camera != null:
        _expect(is_equal_approx(camera.follow_distance, 4.25), "Prototype camera should use original-informed close follow distance.")
        _expect(is_equal_approx(camera.fov, 60.0), "Prototype camera should match original CameraArcVoulu.")
    _expect(world.get_node_or_null("Sun") != null, "Prototype world did not create lighting.")
    _expect(world.has_meta("wmb_manifest_counts"), "Prototype world did not read WMB manifest metadata.")
    var audio := root.get_node_or_null("Audio")
    if audio != null:
        audio.stop_music()
    world.queue_free()
    await process_frame


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)
