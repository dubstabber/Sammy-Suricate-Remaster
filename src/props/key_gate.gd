extends StaticBody3D
class_name KeyGate

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")

@export var required_key_id: int = 3
@export var strict_match: bool = true
@export var open_sound_asset_id: String = "sfx.door_open"
@export var open_height: float = 2.2
@export var open_speed: float = 5.0

var _open := false
var _closed_visual_position := Vector3.ZERO

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: MeshInstance3D = $GateVisual
@onready var _trigger: Area3D = $OpenTrigger


func _ready() -> void:
	add_to_group("key_gate")
	_closed_visual_position = _visual.position if _visual != null else Vector3.ZERO
	if _trigger != null:
		_trigger.body_entered.connect(_on_trigger_body_entered)
	_apply_key_color()


func _process(delta: float) -> void:
	if _visual == null:
		return
	var target := _closed_visual_position
	if _open:
		target.y += open_height
	_visual.position = _visual.position.move_toward(target, open_speed * maxf(delta, 0.0))


func try_open(player: Node) -> bool:
	if _open:
		return true
	if not can_player_open(player):
		return false
	_open = true
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	_play_sfx(open_sound_asset_id)
	return true


func can_player_open(player: Node) -> bool:
	if player == null:
		return false
	if player.has_method("can_open_key_gate"):
		return bool(player.call("can_open_key_gate", required_key_id, strict_match))
	if player.has_method("get_current_key_id"):
		return KEY_RULES.can_open_gate(int(player.call("get_current_key_id")), required_key_id, strict_match)
	return false


func is_open() -> bool:
	return _open


func get_required_key_id() -> int:
	return required_key_id


func is_strict_match() -> bool:
	return strict_match


func _on_trigger_body_entered(body: Node3D) -> void:
	try_open(body)


func _apply_key_color() -> void:
	if _visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = KEY_RULES.key_color(required_key_id)
	material.roughness = 0.75
	_visual.material_override = material


func _play_sfx(asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
