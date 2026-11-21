extends Control

signal level_selected(level_data: Dictionary)
signal back_requested()

const MenuLevelCatalog := preload("res://src/menu/menu_level_catalog.gd")

@export var title_label_path: NodePath = ^"Panel/Margin/VBox/TitleLabel"
@export var detail_label_path: NodePath = ^"Panel/Margin/VBox/DetailLabel"
@export var grid_path: NodePath = ^"Panel/Margin/VBox/Grid"
@export var back_button_path: NodePath = ^"Panel/Margin/VBox/Footer/BackButton"

var _current_category: StringName = &""
var _title_label: Label
var _detail_label: Label
var _grid: GridContainer
var _back_button: BaseButton
var _visible_levels: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	_resolve_nodes()
	_wire_back_button()
	_wire_progress_updates()
	hide_category()


func show_category(category_key: StringName) -> void:
	if not MenuLevelCatalog.has_category(category_key):
		hide_category()
		return

	_current_category = category_key
	_visible_levels = _decorated_levels(MenuLevelCatalog.levels_for_category(category_key))
	_rebuild_buttons()
	_update_title()
	_update_detail({})
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_category() -> void:
	_current_category = &""
	_visible_levels.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_buttons()
	_update_detail({})


func get_current_category() -> StringName:
	return _current_category


func get_visible_level_count() -> int:
	return _visible_levels.size()


func get_level_button(level_number: int) -> BaseButton:
	if _grid == null:
		return null
	return _grid.get_node_or_null("LevelButton%d" % level_number) as BaseButton


func get_level_data_for_number(level_number: int) -> Dictionary:
	return MenuLevelCatalog.level_by_number(level_number)


func _build_interface() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 96.0
	panel.offset_top = 604.0
	panel.offset_right = -96.0
	panel.offset_bottom = -44.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	var detail := Label.new()
	detail.name = "DetailLabel"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 16)
	vbox.add_child(detail)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 36.0)
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	footer.add_child(back)


## Applies saved unlock state / best scores from Game (falls back to the
## static catalog when Game is not available, e.g. isolated tests).
func _decorated_levels(levels: Array[Dictionary]) -> Array[Dictionary]:
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method("decorate_level_entry"):
		return levels
	var decorated: Array[Dictionary] = []
	for level_data: Dictionary in levels:
		decorated.append(game.call("decorate_level_entry", level_data))
	return decorated


func _wire_progress_updates() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_signal("level_progress_changed") and not game.is_connected("level_progress_changed", _on_level_progress_changed):
		game.connect("level_progress_changed", _on_level_progress_changed)


func _on_level_progress_changed() -> void:
	if visible and not _current_category.is_empty():
		show_category(_current_category)


func _resolve_nodes() -> void:
	_title_label = get_node_or_null(title_label_path) as Label
	_detail_label = get_node_or_null(detail_label_path) as Label
	_grid = get_node_or_null(grid_path) as GridContainer
	_back_button = get_node_or_null(back_button_path) as BaseButton


func _wire_back_button() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)


func _rebuild_buttons() -> void:
	_clear_buttons()
	if _grid == null:
		return
	for level_data: Dictionary in _visible_levels:
		_grid.add_child(_create_level_button(level_data))


func _clear_buttons() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _create_level_button(level_data: Dictionary) -> Button:
	var level_number := int(level_data["level_number"])
	var button := Button.new()
	button.name = "LevelButton%d" % level_number
	button.text = "%02d" % level_number
	button.tooltip_text = "%s - %s" % [String(level_data["display_name"]), String(level_data["source_wmb"])]
	button.custom_minimum_size = Vector2(104.0, 44.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = not bool(level_data.get("selectable", true))
	button.pressed.connect(_on_level_pressed.bind(level_data))
	button.mouse_entered.connect(_update_detail.bind(level_data))
	button.focus_entered.connect(_update_detail.bind(level_data))
	return button


func _update_title() -> void:
	if _title_label != null:
		_title_label.text = MenuLevelCatalog.title_for_category(_current_category)


func _update_detail(level_data: Dictionary) -> void:
	if _detail_label == null:
		return
	if level_data.is_empty():
		_detail_label.text = ""
		return
	var detail := "%s  |  %s" % [String(level_data["display_name"]), String(level_data["source_wmb"])]
	if not bool(level_data.get("available", true)):
		detail += "  |  not converted"
	elif not bool(level_data.get("unlocked", true)):
		# interfac.wdl LevelNotReady: the previous level must be won first.
		detail += "  |  win the previous level first"
	elif int(level_data.get("best_score", 0)) > 0:
		detail += "  |  best %d" % int(level_data["best_score"])
	_detail_label.text = detail


func _on_level_pressed(level_data: Dictionary) -> void:
	level_selected.emit(level_data.duplicate(true))


func _on_back_pressed() -> void:
	back_requested.emit()
