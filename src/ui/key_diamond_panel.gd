extends CanvasLayer
class_name KeyDiamondPanel

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")

@export var player_path: NodePath
@export var screen_position: Vector2 = Vector2(18.0, 16.0)
@export var panel_background_asset_id: String = "texture.ui.gem_panel_background"
@export var panel_bar_asset_id: String = "texture.ui.gem_panel_bar"

var _background: Sprite2D
var _key_sprite: Sprite2D
var _key_atlas: AtlasTexture
var _player: Node
var _displayed_key_id := KEY_RULES.KEY_NONE


func _ready() -> void:
	layer = 10
	_background = Sprite2D.new()
	_background.name = "GemPanelBackground"
	_background.centered = false
	_background.position = screen_position
	add_child(_background)

	_key_atlas = AtlasTexture.new()
	_key_sprite = Sprite2D.new()
	_key_sprite.name = "GemPanelKey"
	_key_sprite.centered = false
	_key_sprite.position = screen_position + Vector2(30.0, 24.0)
	_key_sprite.texture = _key_atlas
	add_child(_key_sprite)

	_load_textures()
	_resolve_player()
	_update_panel()


func _process(_delta: float) -> void:
	if _player == null:
		_resolve_player()
	_update_panel()


func is_showing_key() -> bool:
	return _displayed_key_id != KEY_RULES.KEY_NONE


func get_displayed_key_id() -> int:
	return _displayed_key_id


func get_displayed_panel_slot() -> int:
	return KEY_RULES.panel_slot(_displayed_key_id)


func _load_textures() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	_background.texture = assets.load_asset(panel_background_asset_id) as Texture2D
	_key_atlas.atlas = assets.load_asset(panel_bar_asset_id) as Texture2D


func _resolve_player() -> void:
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")


func _update_panel() -> void:
	var key_id := KEY_RULES.KEY_NONE
	if _player != null and _player.has_method("get_current_key_id"):
		key_id = int(_player.call("get_current_key_id"))
	_displayed_key_id = key_id
	var visible_key := key_id != KEY_RULES.KEY_NONE
	_background.visible = visible_key
	_key_sprite.visible = visible_key
	if visible_key:
		var slot := KEY_RULES.panel_slot(key_id)
		_key_atlas.region = Rect2(float(slot * KEY_RULES.PANEL_SLOT_WIDTH), 0.0, float(KEY_RULES.PANEL_SLOT_WIDTH), float(KEY_RULES.PANEL_SLOT_WIDTH))
