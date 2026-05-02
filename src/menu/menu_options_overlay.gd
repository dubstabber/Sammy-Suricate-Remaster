extends CanvasLayer
class_name MenuOptionsOverlay

signal options_closed()
signal quit_confirmed()
signal quit_cancelled()

@export var options_panel_path: NodePath = ^"OptionsPanel"
@export var quit_confirm_path: NodePath = ^"QuitConfirm"
@export var music_slider_path: NodePath = ^"OptionsPanel/MusicSlider"
@export var sfx_slider_path: NodePath = ^"OptionsPanel/SfxSlider"
@export var back_button_path: NodePath = ^"OptionsPanel/BackButton"
@export var resume_button_path: NodePath = ^"OptionsPanel/ResumeButton"
@export var quit_button_path: NodePath = ^"OptionsPanel/QuitButton"
@export var yes_button_path: NodePath = ^"QuitConfirm/YesButton"
@export var no_button_path: NodePath = ^"QuitConfirm/NoButton"

var _options_panel: Control
var _quit_confirm: Control
var _music_slider: Slider
var _sfx_slider: Slider


func _ready() -> void:
	_options_panel = get_node_or_null(options_panel_path) as Control
	_quit_confirm = get_node_or_null(quit_confirm_path) as Control
	_music_slider = get_node_or_null(music_slider_path) as Slider
	_sfx_slider = get_node_or_null(sfx_slider_path) as Slider
	_connect_button(back_button_path, _on_close_requested)
	_connect_button(resume_button_path, _on_close_requested)
	_connect_button(quit_button_path, show_quit_confirm)
	_connect_button(yes_button_path, _on_quit_yes)
	_connect_button(no_button_path, _on_quit_no)
	_wire_sliders()
	hide_options()
	hide_quit_confirm()


func show_options() -> void:
	if _options_panel == null:
		return
	_sync_sliders_from_audio()
	_options_panel.visible = true
	hide_quit_confirm()


func hide_options() -> void:
	if _options_panel != null:
		_options_panel.visible = false


func is_options_visible() -> bool:
	return _options_panel != null and _options_panel.visible


func show_quit_confirm() -> void:
	if _quit_confirm != null:
		_quit_confirm.visible = true


func hide_quit_confirm() -> void:
	if _quit_confirm != null:
		_quit_confirm.visible = false


func is_quit_confirm_visible() -> bool:
	return _quit_confirm != null and _quit_confirm.visible


func get_music_volume_percent() -> float:
	return _music_slider.value if _music_slider != null else 100.0


func get_sfx_volume_percent() -> float:
	return _sfx_slider.value if _sfx_slider != null else 100.0


func _connect_button(path: NodePath, callback: Callable) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button == null:
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _wire_sliders() -> void:
	if _music_slider != null and not _music_slider.value_changed.is_connected(_on_music_volume_changed):
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if _sfx_slider != null and not _sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_sync_sliders_from_audio()


func _sync_sliders_from_audio() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	if _music_slider != null and audio.has_method("get_music_volume_percent"):
		_music_slider.set_value_no_signal(float(audio.call("get_music_volume_percent")))
	if _sfx_slider != null and audio.has_method("get_sfx_volume_percent"):
		_sfx_slider.set_value_no_signal(float(audio.call("get_sfx_volume_percent")))


func _on_music_volume_changed(value: float) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("set_music_volume_percent"):
		audio.call("set_music_volume_percent", value)


func _on_sfx_volume_changed(value: float) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("set_sfx_volume_percent"):
		audio.call("set_sfx_volume_percent", value)


func _on_close_requested() -> void:
	hide_quit_confirm()
	hide_options()
	options_closed.emit()


func _on_quit_yes() -> void:
	quit_confirmed.emit()


func _on_quit_no() -> void:
	hide_quit_confirm()
	quit_cancelled.emit()
