extends CanvasLayer

signal resume_requested()
signal restart_requested()
signal main_menu_requested()
signal quit_requested()

const BACKGROUND_TEXTURE_ID := "texture.menu.options.background"
const RESUME_TEXTURE_ID := "texture.menu.options.resume"
const RESUME_HOVER_TEXTURE_ID := "texture.menu.options.resume_hover"
const RESTART_TEXTURE_ID := "texture.menu.options.restart"
const RESTART_HOVER_TEXTURE_ID := "texture.menu.options.restart_hover"
const BACK_TEXTURE_ID := "texture.menu.options.back"
const BACK_HOVER_TEXTURE_ID := "texture.menu.options.back_hover"
const QUIT_TEXTURE_ID := "texture.menu.quit"
const QUIT_HOVER_TEXTURE_ID := "texture.menu.quit_hover"
const YES_TEXTURE_ID := "texture.menu.options.quit"
const YES_HOVER_TEXTURE_ID := "texture.menu.options.quit_hover"
const NO_TEXTURE_ID := "texture.menu.options.no"
const NO_HOVER_TEXTURE_ID := "texture.menu.options.no_hover"
const CONFIRM_BACKGROUND_TEXTURE_ID := "texture.menu.options.quit_prompt"
const CONFIRM_RESTART: StringName = &"restart"
const CONFIRM_QUIT: StringName = &"quit"

@export var options_panel_path: NodePath = ^"OptionsPanel"
@export var confirm_panel_path: NodePath = ^"ConfirmPanel"
@export var resume_button_path: NodePath = ^"OptionsPanel/ResumeButton"
@export var restart_button_path: NodePath = ^"OptionsPanel/RestartButton"
@export var back_button_path: NodePath = ^"OptionsPanel/BackButton"
@export var quit_button_path: NodePath = ^"OptionsPanel/QuitButton"
@export var yes_button_path: NodePath = ^"ConfirmPanel/YesButton"
@export var no_button_path: NodePath = ^"ConfirmPanel/NoButton"

var _options_panel: Control
var _confirm_panel: Control
var _confirm_label: Label
var _menu_buttons: Array[BaseButton] = []
var _confirm_buttons: Array[BaseButton] = []
var _confirm_action: StringName = &""
var _focused_button: BaseButton


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30


func _ready() -> void:
	_build_overlay()
	hide_pause_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("menu_cancel"):
		if is_confirm_visible():
			hide_confirm()
		else:
			resume_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_forward"):
		_focus_relative(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_back"):
		_focus_relative(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		if _focused_button != null:
			_focused_button.pressed.emit()
		get_viewport().set_input_as_handled()


func show_pause_menu() -> void:
	visible = true
	if _options_panel != null:
		_options_panel.visible = true
	hide_confirm()
	_focus_first_menu_button()


func hide_pause_menu() -> void:
	hide_confirm()
	if _options_panel != null:
		_options_panel.visible = false
	visible = false
	_focused_button = null


func is_pause_menu_visible() -> bool:
	return visible and _options_panel != null and _options_panel.visible


func show_restart_confirm() -> void:
	_show_confirm(CONFIRM_RESTART, "Restart?")


func show_quit_confirm() -> void:
	_show_confirm(CONFIRM_QUIT, "Quit?")


func hide_confirm() -> void:
	_confirm_action = &""
	if _confirm_panel != null:
		_confirm_panel.visible = false
	if visible:
		_focus_first_menu_button()


func is_confirm_visible() -> bool:
	return _confirm_panel != null and _confirm_panel.visible


func _build_overlay() -> void:
	if get_node_or_null(options_panel_path) == null:
		add_child(_create_options_panel())
	if get_node_or_null(confirm_panel_path) == null:
		add_child(_create_confirm_panel())

	_options_panel = get_node_or_null(options_panel_path) as Control
	_confirm_panel = get_node_or_null(confirm_panel_path) as Control
	_confirm_label = get_node_or_null(^"ConfirmPanel/PromptLabel") as Label
	_menu_buttons = [
		get_node_or_null(resume_button_path) as BaseButton,
		get_node_or_null(restart_button_path) as BaseButton,
		get_node_or_null(back_button_path) as BaseButton,
		get_node_or_null(quit_button_path) as BaseButton
	]
	_confirm_buttons = [
		get_node_or_null(yes_button_path) as BaseButton,
		get_node_or_null(no_button_path) as BaseButton
	]

	_connect_button(resume_button_path, _on_resume_pressed)
	_connect_button(restart_button_path, show_restart_confirm)
	_connect_button(back_button_path, _on_back_pressed)
	_connect_button(quit_button_path, show_quit_confirm)
	_connect_button(yes_button_path, _on_yes_pressed)
	_connect_button(no_button_path, _on_no_pressed)


func _create_options_panel() -> Control:
	var panel := Control.new()
	panel.name = "OptionsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = _load_texture(BACKGROUND_TEXTURE_ID)
	background.set_anchors_preset(Control.PRESET_CENTER)
	background.offset_left = -320.0
	background.offset_top = -240.0
	background.offset_right = 320.0
	background.offset_bottom = 240.0
	panel.add_child(background)

	panel.add_child(_create_texture_button("RestartButton", RESTART_TEXTURE_ID, RESTART_HOVER_TEXTURE_ID, -272.0, 28.0, Vector2(204.0, 50.0)))
	panel.add_child(_create_texture_button("ResumeButton", RESUME_TEXTURE_ID, RESUME_HOVER_TEXTURE_ID, -320.0, 95.0, Vector2(306.0, 42.0)))
	panel.add_child(_create_texture_button("BackButton", BACK_TEXTURE_ID, BACK_HOVER_TEXTURE_ID, -320.0, 137.0, Vector2(306.0, 40.0)))
	panel.add_child(_create_texture_button("QuitButton", QUIT_TEXTURE_ID, QUIT_HOVER_TEXTURE_ID, -320.0, 177.0, Vector2(306.0, 41.0)))
	return panel


func _create_confirm_panel() -> Control:
	var panel := Control.new()
	panel.name = "ConfirmPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var prompt := TextureRect.new()
	prompt.name = "Prompt"
	prompt.texture = _load_texture(CONFIRM_BACKGROUND_TEXTURE_ID)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.offset_left = -100.0
	prompt.offset_top = -112.0
	prompt.offset_right = 100.0
	prompt.offset_bottom = -44.0
	panel.add_child(prompt)

	var label := Label.new()
	label.name = "PromptLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -100.0
	label.offset_top = -112.0
	label.offset_right = 100.0
	label.offset_bottom = -44.0
	panel.add_child(label)

	panel.add_child(_create_texture_button("YesButton", YES_TEXTURE_ID, YES_HOVER_TEXTURE_ID, -140.0, 24.0, Vector2(68.0, 28.0)))
	panel.add_child(_create_texture_button("NoButton", NO_TEXTURE_ID, NO_HOVER_TEXTURE_ID, 30.0, 24.0, Vector2(68.0, 28.0)))
	return panel


func _create_texture_button(
		node_name: String,
		normal_asset_id: String,
		hover_asset_id: String,
		left: float,
		top: float,
		fallback_size: Vector2
) -> TextureButton:
	var normal_texture := _load_texture(normal_asset_id)
	var hover_texture := _load_texture(hover_asset_id)
	var button := TextureButton.new()
	button.name = node_name
	button.texture_normal = normal_texture
	button.texture_hover = hover_texture
	button.texture_focused = hover_texture
	button.texture_pressed = hover_texture
	button.ignore_texture_size = false
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_anchors_preset(Control.PRESET_CENTER)
	var button_size := fallback_size
	if normal_texture != null:
		button_size = normal_texture.get_size()
	button.offset_left = left
	button.offset_top = top
	button.offset_right = left + button_size.x
	button.offset_bottom = top + button_size.y
	return button


func _load_texture(asset_id: String) -> Texture2D:
	var assets := get_node_or_null("/root/Assets")
	if assets != null and assets.has_method("load_asset"):
		var texture := assets.call("load_asset", asset_id) as Texture2D
		if texture != null:
			return texture
	return load(_fallback_texture_path(asset_id)) as Texture2D


func _fallback_texture_path(asset_id: String) -> String:
	match asset_id:
		BACKGROUND_TEXTURE_ID:
			return "res://assets/textures/menu/options/fondopt1.png"
		RESUME_TEXTURE_ID:
			return "res://assets/textures/menu/options/resum1.png"
		RESUME_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/options/resum2.png"
		RESTART_TEXTURE_ID:
			return "res://assets/textures/menu/options/restart2.png"
		RESTART_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/options/restart3.png"
		BACK_TEXTURE_ID:
			return "res://assets/textures/menu/options/back1.png"
		BACK_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/options/back2.png"
		QUIT_TEXTURE_ID:
			return "res://assets/textures/menu/quit1.png"
		QUIT_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/quit2.png"
		YES_TEXTURE_ID:
			return "res://assets/textures/menu/options/oui1.png"
		YES_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/options/oui2.png"
		NO_TEXTURE_ID:
			return "res://assets/textures/menu/options/non1.png"
		NO_HOVER_TEXTURE_ID:
			return "res://assets/textures/menu/options/non2.png"
		CONFIRM_BACKGROUND_TEXTURE_ID:
			return "res://assets/textures/menu/options/fondyn.png"
	return ""


func _connect_button(path: NodePath, callback: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button == null:
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _show_confirm(action: StringName, prompt_text: String) -> void:
	_confirm_action = action
	if _confirm_label != null:
		_confirm_label.text = prompt_text
	if _confirm_panel != null:
		_confirm_panel.visible = true
	var no_button := get_node_or_null(no_button_path) as BaseButton
	if no_button != null:
		_focus_button(no_button)


func _focus_first_menu_button() -> void:
	for button in _menu_buttons:
		if button != null and button.visible:
			_focus_button(button)
			return


func _focus_relative(direction: int) -> void:
	var buttons := _confirm_buttons if is_confirm_visible() else _menu_buttons
	var valid_buttons: Array[BaseButton] = []
	for button in buttons:
		if button != null and button.visible:
			valid_buttons.append(button)
	if valid_buttons.is_empty():
		return

	var current_index := valid_buttons.find(_focused_button)
	if current_index < 0:
		current_index = 0
	else:
		current_index = wrapi(current_index + direction, 0, valid_buttons.size())
	_focus_button(valid_buttons[current_index])


func _focus_button(button: BaseButton) -> void:
	_focused_button = button
	button.grab_focus()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_back_pressed() -> void:
	main_menu_requested.emit()


func _on_yes_pressed() -> void:
	match _confirm_action:
		CONFIRM_RESTART:
			restart_requested.emit()
		CONFIRM_QUIT:
			quit_requested.emit()


func _on_no_pressed() -> void:
	hide_confirm()
