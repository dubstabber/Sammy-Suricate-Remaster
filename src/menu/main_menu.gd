extends Node

signal menu_action_selected(action_id: int, action_key: StringName)

const Menu3DItemScript := preload("res://src/menu/menu_3d_item.gd")
const MenuOptionsOverlayScript := preload("res://src/menu/menu_options_overlay.gd")
const MenuMetadata := preload("res://src/menu/menu_wmb_metadata.gd")
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"
const CAMERA_TWEEN_SECONDS := 0.55
const BACK_ITEM_NAME := "BackItem"
const MENU_MUSIC_ASSET_ID := "music.sammy01"
const BACK_ARROW_TEXTURE_ID := "texture.menu.back_arrow"
const DEBUG_PROTOTYPE_ACTION_ID := 9001
const DEBUG_PROTOTYPE_ACTION_KEY := &"debug_prototype"

@export var menu_items_root_path: NodePath = ^"World/MenuItems"
@export var camera_path: NodePath = ^"World/Camera3D"
@export var overlay_path: NodePath = ^"MenuOverlay"
@export var branch_overlay_path: NodePath = ^"BranchOverlay"
@export var debug_overlay_path: NodePath = ^"DebugOverlay"
@export var play_menu_music := true

var last_selected_action_id := 0
var last_selected_action_key: StringName = &""
var _current_hub_view: StringName = MenuMetadata.HUB_VIEW_MAIN
var _camera_tween: Tween
var _back_item: Area3D
var _overlay: Node
var _branch_overlay: CanvasLayer
var _debug_overlay: CanvasLayer
var _debug_prototype_button: BaseButton


func _ready() -> void:
	_register_current_scene()
	_rebuild_menu_items()
	_ensure_options_overlay()
	_ensure_branch_overlay()
	_ensure_debug_overlay()
	_wire_menu_items()
	_wire_overlay()
	_wire_debug_overlay()
	_apply_camera_view(MenuMetadata.HUB_VIEW_MAIN, false)
	_update_branch_state()
	_start_menu_music()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		handle_cancel()


func get_menu_item_count() -> int:
	var root_node := get_node_or_null(menu_items_root_path)
	if root_node == null:
		return 0
	var count := 0
	for child in root_node.get_children():
		if child.has_signal("selected"):
			count += 1
	return count


func get_last_selected_action_id() -> int:
	return last_selected_action_id


func get_last_selected_action_key() -> StringName:
	return last_selected_action_key


func get_current_hub_view() -> StringName:
	return _current_hub_view


func is_options_visible() -> bool:
	return _overlay != null and _overlay.has_method("is_options_visible") and bool(_overlay.call("is_options_visible"))


func is_quit_confirm_visible() -> bool:
	return _overlay != null and _overlay.has_method("is_quit_confirm_visible") and bool(_overlay.call("is_quit_confirm_visible"))


func request_play() -> Error:
	if last_selected_action_id != MenuMetadata.ACTION_PLAY:
		last_selected_action_id = MenuMetadata.ACTION_PLAY
		last_selected_action_key = &"play"
		menu_action_selected.emit(last_selected_action_id, last_selected_action_key)
	return _route_to_prototype_world()


func request_debug_prototype() -> Error:
	last_selected_action_id = DEBUG_PROTOTYPE_ACTION_ID
	last_selected_action_key = DEBUG_PROTOTYPE_ACTION_KEY
	menu_action_selected.emit(last_selected_action_id, last_selected_action_key)
	return _route_to_prototype_world()


func _route_to_prototype_world() -> Error:
	if bool(ProjectSettings.get_setting("sammy/test/skip_menu_routes", false)):
		return OK

	_stop_menu_music()
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("show_prototype_world"):
		return int(game.call("show_prototype_world"))
	return get_tree().change_scene_to_file(PROTOTYPE_SCENE_PATH)


func select_action(action_key: StringName) -> void:
	var root_node := get_node_or_null(menu_items_root_path)
	if root_node == null:
		return
	for child in root_node.get_children():
		if child is Area3D and child.has_method("select") and child.get("action_key") == action_key:
			child.call("select")
			return


func handle_cancel() -> void:
	if is_quit_confirm_visible():
		_hide_quit_confirm()
	elif is_options_visible():
		_hide_options()
	elif _current_hub_view != MenuMetadata.HUB_VIEW_MAIN:
		_show_hub_view(MenuMetadata.HUB_VIEW_MAIN)
	else:
		_show_quit_confirm()


func _register_current_scene() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("set_current_scene"):
		game.call("set_current_scene", self)


func _rebuild_menu_items() -> void:
	var root_node := get_node_or_null(menu_items_root_path) as Node3D
	if root_node == null:
		return
	for child in root_node.get_children():
		root_node.remove_child(child)
		child.queue_free()
	for item_data: Dictionary in MenuMetadata.MENU_ITEMS:
		root_node.add_child(_create_wmb_item(item_data))
	for part_data: Dictionary in MenuMetadata.MENU_COMPANION_PARTS:
		root_node.add_child(_create_wmb_item(part_data))
	_back_item = _create_back_item()
	root_node.add_child(_back_item)


func _create_wmb_item(item_data: Dictionary) -> Area3D:
	var item := Menu3DItemScript.new() as Area3D
	item.name = String(item_data["node_name"])
	item.position = item_data["position"]
	if item_data.has("rotation_degrees"):
		item.rotation_degrees = item_data["rotation_degrees"]
	if item_data.has("scale"):
		item.scale = item_data["scale"]
	item.collision_layer = 1
	item.collision_mask = 0
	item.set("action_id", int(item_data["action_id"]))
	item.set("action_key", StringName(item_data["action_key"]))
	item.set("original_source_name", "%s:%s" % [MenuMetadata.SOURCE_LEVEL, String(item_data["source_wmb"])])
	item.set("source_position", item_data["source_position"])
	item.set("model_scene", _load_menu_model(String(item_data["asset_id"])))
	item.set("hover_lift", float(item_data["hover_lift"]))
	item.set("hover_scale", float(item_data["hover_scale"]))
	item.set("animated", bool(item_data.get("animated", false)))
	item.set("source_skill2", float(item_data.get("source_skill2", 0.0)))
	item.set("source_skill3", float(item_data.get("source_skill3", 0.0)))
	item.set("source_skill4", float(item_data.get("source_skill4", 0.0)))
	item.set("source_skill7", float(item_data.get("source_skill7", 0.0)))
	item.set("animation_phase_offset", float(item_data.get("animation_phase_offset", 0.0)))
	item.add_child(_create_collision_shape(item_data["collision_size"]))
	item.add_child(_create_hover_light())
	if not bool(item_data.get("visible_by_default", true)):
		item.visible = false
		item.set("disabled", true)
	return item


func _create_back_item() -> Area3D:
	var item := Menu3DItemScript.new() as Area3D
	item.name = BACK_ITEM_NAME
	item.position = Vector3(0.0, -2.0, -4.6)
	item.collision_layer = 1
	item.collision_mask = 0
	item.set("action_id", MenuMetadata.ACTION_BACK)
	item.set("action_key", &"back")
	item.set("original_source_name", "paninter.wdl:Skill1=20 Back")
	item.set("source_position", Vector3.ZERO)
	item.set("hover_lift", 0.0)
	item.set("hover_scale", 1.0)
	item.add_child(_create_back_sprite())
	item.add_child(_create_collision_shape(Vector3(1.2, 0.7, 0.2)))
	item.add_child(_create_hover_light())
	return item


func _create_collision_shape(size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	return collision


func _create_hover_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "HoverLight"
	# interfac.wdl ObjetMenuSelect sets LightRed/Green/Blue to 255/180/50
	# and LightRange to 300. Main menu entities do not scale on hover.
	light.light_color = Color(1.0, 0.706, 0.196)
	light.light_energy = 2.6
	light.omni_range = 4.2
	light.position = Vector3(0.0, 0.25, 0.7)
	light.visible = false
	return light


func _create_back_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "Model"
	sprite.texture = _load_texture(BACK_ARROW_TEXTURE_ID)
	sprite.pixel_size = 0.006
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.double_sided = true
	return sprite


func _load_menu_model(asset_id: String) -> PackedScene:
	var assets := get_node_or_null("/root/Assets")
	if assets != null and assets.has_method("load_asset"):
		return assets.call("load_asset", asset_id) as PackedScene
	return load(_fallback_asset_path(asset_id)) as PackedScene


func _load_texture(asset_id: String) -> Texture2D:
	var assets := get_node_or_null("/root/Assets")
	if assets != null and assets.has_method("load_asset"):
		return assets.call("load_asset", asset_id) as Texture2D
	return load(_fallback_asset_path(asset_id)) as Texture2D


func _fallback_asset_path(asset_id: String) -> String:
	match asset_id:
		"texture.menu.back_arrow":
			return "res://assets/textures/menu/options/mflechA1.png"
		"texture.menu.options.background":
			return "res://assets/textures/menu/options/fondopt1.png"
		"texture.menu.options.audio":
			return "res://assets/textures/menu/options/audio1.png"
		"texture.menu.options.resume":
			return "res://assets/textures/menu/options/resum1.png"
		"texture.menu.options.resume_hover":
			return "res://assets/textures/menu/options/resum2.png"
		"texture.menu.options.back":
			return "res://assets/textures/menu/options/back1.png"
		"texture.menu.options.back_hover":
			return "res://assets/textures/menu/options/back2.png"
		"texture.menu.options.quit":
			return "res://assets/textures/menu/options/oui1.png"
		"texture.menu.options.quit_hover":
			return "res://assets/textures/menu/options/oui2.png"
		"texture.menu.options.no":
			return "res://assets/textures/menu/options/non1.png"
		"texture.menu.options.no_hover":
			return "res://assets/textures/menu/options/non2.png"
		"texture.menu.options.quit_prompt":
			return "res://assets/textures/menu/options/fondyn.png"
		"model.menu.item.play":
			return "res://assets/models/menu/items/titplay/titplay.gltf"
		"model.menu.item.play_gem_1":
			return "res://assets/models/menu/items/titplay2/titplay2.gltf"
		"model.menu.item.play_gem_2":
			return "res://assets/models/menu/items/titplay3/titplay3.gltf"
		"model.menu.item.tutorial":
			return "res://assets/models/menu/items/tittutor/tittutor.gltf"
		"model.menu.item.tutorial_gem":
			return "res://assets/models/menu/items/tittuto2/tittuto2.gltf"
		"model.menu.item.jump":
			return "res://assets/models/menu/items/titjump/titjump.gltf"
		"model.menu.item.jump_gem":
			return "res://assets/models/menu/items/titjum2/titjum2.gltf"
		"model.menu.item.think":
			return "res://assets/models/menu/items/titpuzzl/titpuzzl.gltf"
		"model.menu.item.think_gem":
			return "res://assets/models/menu/items/titpuzz2/titpuzz2.gltf"
		"model.menu.item.bonus":
			return "res://assets/models/menu/items/titbonus/titbonus.gltf"
		"model.menu.item.bonus_gem":
			return "res://assets/models/menu/items/titbonu2/titbonu2.gltf"
		"model.menu.item.options":
			return "res://assets/models/menu/items/titoptio/titoptio.gltf"
		"model.menu.item.quit":
			return "res://assets/models/menu/items/titquit/titquit.gltf"
	return ""


func _wire_menu_items() -> void:
	var root_node := get_node_or_null(menu_items_root_path)
	if root_node == null:
		return
	var callback := Callable(self, "_on_menu_item_selected")
	for child in root_node.get_children():
		if child.has_signal("selected") and not child.is_connected("selected", callback):
			child.connect("selected", callback)


func _ensure_options_overlay() -> void:
	_overlay = get_node_or_null(overlay_path)
	if _overlay != null:
		return
	var overlay := MenuOptionsOverlayScript.new()
	overlay.name = String(overlay_path)
	overlay.add_child(_create_options_panel())
	overlay.add_child(_create_quit_confirm_panel())
	add_child(overlay)
	_overlay = overlay


func _create_options_panel() -> Control:
	var panel := Control.new()
	panel.name = "OptionsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = _load_texture("texture.menu.options.background")
	background.set_anchors_preset(Control.PRESET_CENTER)
	background.offset_left = -320.0
	background.offset_top = -240.0
	background.offset_right = 320.0
	background.offset_bottom = 240.0
	panel.add_child(background)

	var audio_label := TextureRect.new()
	audio_label.name = "AudioLabel"
	audio_label.texture = _load_texture("texture.menu.options.audio")
	audio_label.set_anchors_preset(Control.PRESET_CENTER)
	audio_label.offset_left = -260.0
	audio_label.offset_top = -118.0
	audio_label.offset_right = -90.0
	audio_label.offset_bottom = -64.0
	panel.add_child(audio_label)

	panel.add_child(_create_slider("MusicSlider", -56.0, 82.0))
	panel.add_child(_create_slider("SfxSlider", 24.0, 82.0))
	panel.add_child(_create_texture_button("ResumeButton", "texture.menu.options.resume", "texture.menu.options.resume_hover", -240.0, 142.0))
	panel.add_child(_create_texture_button("BackButton", "texture.menu.options.back", "texture.menu.options.back_hover", -20.0, 142.0))
	panel.add_child(_create_texture_button("QuitButton", "texture.menu.options.quit", "texture.menu.options.quit_hover", 198.0, 142.0))
	return panel


func _create_quit_confirm_panel() -> Control:
	var panel := Control.new()
	panel.name = "QuitConfirm"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var prompt := TextureRect.new()
	prompt.name = "Prompt"
	prompt.texture = _load_texture("texture.menu.options.quit_prompt")
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.offset_left = -100.0
	prompt.offset_top = -112.0
	prompt.offset_right = 100.0
	prompt.offset_bottom = -44.0
	panel.add_child(prompt)

	panel.add_child(_create_texture_button("YesButton", "texture.menu.options.quit", "texture.menu.options.quit_hover", -140.0, 24.0))
	panel.add_child(_create_texture_button("NoButton", "texture.menu.options.no", "texture.menu.options.no_hover", 30.0, 24.0))
	return panel


func _create_slider(node_name: String, top: float, width: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.set_anchors_preset(Control.PRESET_CENTER)
	slider.offset_left = -70.0
	slider.offset_top = top
	slider.offset_right = -70.0 + width
	slider.offset_bottom = top + 24.0
	return slider


func _create_texture_button(
		node_name: String,
		normal_asset_id: String,
		hover_asset_id: String,
		left: float,
		top: float
) -> TextureButton:
	var button := TextureButton.new()
	button.name = node_name
	button.texture_normal = _load_texture(normal_asset_id)
	button.texture_hover = _load_texture(hover_asset_id)
	button.texture_pressed = button.texture_hover
	button.ignore_texture_size = false
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.set_anchors_preset(Control.PRESET_CENTER)
	button.offset_left = left
	button.offset_top = top
	button.offset_right = left + 128.0
	button.offset_bottom = top + 54.0
	return button


func _ensure_branch_overlay() -> void:
	_branch_overlay = get_node_or_null(branch_overlay_path) as CanvasLayer
	if _branch_overlay != null:
		return
	_branch_overlay = CanvasLayer.new()
	_branch_overlay.name = String(branch_overlay_path)
	add_child(_branch_overlay)


func _ensure_debug_overlay() -> void:
	_debug_overlay = get_node_or_null(debug_overlay_path) as CanvasLayer
	if _debug_overlay == null:
		_debug_overlay = CanvasLayer.new()
		_debug_overlay.name = String(debug_overlay_path)
		_debug_overlay.layer = 20
		add_child(_debug_overlay)
	if _debug_overlay.get_node_or_null("DebugPrototypeButton") == null:
		_debug_overlay.add_child(_create_debug_prototype_button())


func _create_debug_prototype_button() -> Button:
	var button := Button.new()
	button.name = "DebugPrototypeButton"
	button.text = "DEBUG: Prototype"
	button.tooltip_text = "Open prototype_world"
	button.custom_minimum_size = Vector2(168.0, 32.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = 12.0
	button.offset_top = 12.0
	button.offset_right = 180.0
	button.offset_bottom = 44.0
	return button


func _wire_overlay() -> void:
	if _overlay == null:
		return
	if _overlay.has_signal("quit_confirmed") and not _overlay.is_connected("quit_confirmed", _on_quit_confirmed):
		_overlay.connect("quit_confirmed", _on_quit_confirmed)
	if _overlay.has_signal("quit_cancelled") and not _overlay.is_connected("quit_cancelled", _on_quit_cancelled):
		_overlay.connect("quit_cancelled", _on_quit_cancelled)


func _wire_debug_overlay() -> void:
	if _debug_overlay == null:
		return
	_debug_prototype_button = _debug_overlay.get_node_or_null("DebugPrototypeButton") as BaseButton
	if _debug_prototype_button != null and not _debug_prototype_button.pressed.is_connected(_on_debug_prototype_pressed):
		_debug_prototype_button.pressed.connect(_on_debug_prototype_pressed)


func _on_menu_item_selected(_item: Area3D, action_id: int, action_key: StringName) -> void:
	last_selected_action_id = action_id
	last_selected_action_key = action_key
	menu_action_selected.emit(action_id, action_key)
	match action_id:
		MenuMetadata.ACTION_PLAY:
			request_play()
		MenuMetadata.ACTION_OPTIONS:
			_show_options()
		MenuMetadata.ACTION_QUIT:
			_show_quit_confirm()
		MenuMetadata.ACTION_BACK:
			_show_hub_view(MenuMetadata.HUB_VIEW_MAIN)
		MenuMetadata.ACTION_TUTORIAL, MenuMetadata.ACTION_JUMP, MenuMetadata.ACTION_THINK, MenuMetadata.ACTION_BONUS:
			_show_hub_view(action_key)


func _on_debug_prototype_pressed() -> void:
	request_debug_prototype()


func _show_hub_view(view_key: StringName) -> void:
	_current_hub_view = view_key
	_apply_camera_view(view_key, true)
	_update_branch_state()


func _apply_camera_view(view_key: StringName, animated: bool) -> void:
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera == null:
		return
	var data := MenuMetadata.camera_for_view(view_key)
	var target_position: Vector3 = data.get("position", camera.position)
	var target_rotation_degrees: Vector3 = data.get("rotation_degrees", camera.rotation_degrees)
	var target_fov := float(data.get("fov", camera.fov))
	if _camera_tween != null:
		_camera_tween.kill()
		_camera_tween = null
	if not animated:
		camera.position = target_position
		camera.rotation_degrees = target_rotation_degrees
		camera.fov = target_fov
		return
	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(camera, "position", target_position, CAMERA_TWEEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "rotation_degrees", target_rotation_degrees, CAMERA_TWEEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "fov", target_fov, CAMERA_TWEEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_branch_state() -> void:
	var in_branch := _current_hub_view != MenuMetadata.HUB_VIEW_MAIN
	if _back_item != null:
		_back_item.visible = in_branch
		if _back_item.has_method("set_disabled"):
			_back_item.call("set_disabled", not in_branch)
	if _branch_overlay != null:
		_branch_overlay.visible = in_branch


func _show_options() -> void:
	if _overlay != null and _overlay.has_method("show_options"):
		_overlay.call("show_options")


func _hide_options() -> void:
	if _overlay != null and _overlay.has_method("hide_options"):
		_overlay.call("hide_options")


func _show_quit_confirm() -> void:
	if _overlay != null and _overlay.has_method("show_quit_confirm"):
		_overlay.call("show_quit_confirm")


func _hide_quit_confirm() -> void:
	if _overlay != null and _overlay.has_method("hide_quit_confirm"):
		_overlay.call("hide_quit_confirm")


func _on_quit_confirmed() -> void:
	if bool(ProjectSettings.get_setting("sammy/test/skip_quit", false)):
		return
	get_tree().quit()


func _on_quit_cancelled() -> void:
	_hide_quit_confirm()


func _start_menu_music() -> void:
	if not play_menu_music or bool(ProjectSettings.get_setting("sammy/test/skip_music", false)):
		return
	if DisplayServer.get_name() == "headless":
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_music"):
		audio.call("play_music", MENU_MUSIC_ASSET_ID, true)


func _stop_menu_music() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("stop_music"):
		audio.call("stop_music")
