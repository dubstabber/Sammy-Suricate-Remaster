extends Node

@export var current_scene_path: NodePath = ^"PrototypeWorld"


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null:
		var current_scene := get_node_or_null(current_scene_path)
		if current_scene == null and get_child_count() > 0:
			current_scene = get_child(0)
		if current_scene != null:
			game.set_current_scene(current_scene)
