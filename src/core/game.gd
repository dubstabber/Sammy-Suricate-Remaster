extends Node

const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"

var current_scene: Node


func set_current_scene(scene: Node) -> void:
    current_scene = scene


func change_to_scene(scene_path: String) -> Error:
    return get_tree().change_scene_to_file(scene_path)


func reload_prototype() -> Error:
    return change_to_scene(PROTOTYPE_SCENE_PATH)
