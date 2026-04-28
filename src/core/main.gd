extends Node

const PROTOTYPE_SCENE := preload("res://scenes/prototype/prototype_world.tscn")


func _ready() -> void:
    if get_child_count() > 0:
        return

    var prototype := PROTOTYPE_SCENE.instantiate()
    add_child(prototype)

    var game := get_node_or_null("/root/Game")
    if game != null:
        game.set_current_scene(prototype)
