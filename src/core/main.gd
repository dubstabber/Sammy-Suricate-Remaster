extends Node

const MAIN_MENU_SCENE_PATH := "res://scenes/menu/main_menu.tscn"
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"

@export_file("*.tscn") var initial_scene_path: String = MAIN_MENU_SCENE_PATH
@export var scene_root_path: NodePath = ^"SceneRoot"


func _ready() -> void:
	_register_scene_router()
	var err := show_scene(initial_scene_path)
	if err != OK:
		push_error("Unable to load initial scene %s: %s" % [initial_scene_path, error_string(err)])


func show_main_menu() -> Error:
	return show_scene(MAIN_MENU_SCENE_PATH)


func show_prototype_world() -> Error:
	return show_scene(PROTOTYPE_SCENE_PATH)


func show_scene(scene_path: String) -> Error:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return ERR_CANT_OPEN

	var scene_root := get_node_or_null(scene_root_path)
	if scene_root == null:
		return ERR_DOES_NOT_EXIST

	for child in scene_root.get_children():
		scene_root.remove_child(child)
		child.queue_free()

	var scene := packed_scene.instantiate()
	scene_root.add_child(scene)
	_set_current_scene(scene)
	return OK


func get_current_scene() -> Node:
	var scene_root := get_node_or_null(scene_root_path)
	if scene_root == null or scene_root.get_child_count() <= 0:
		return null
	return scene_root.get_child(0)


func _register_scene_router() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null:
		if game.has_method("set_scene_router"):
			game.call("set_scene_router", self)


func _set_current_scene(scene: Node) -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("set_current_scene"):
		game.call("set_current_scene", scene)
