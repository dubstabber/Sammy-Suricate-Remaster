extends Node

const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"
const DEFAULT_EYE_OF_TRUTH_SECONDS := 256.0 / 16.0

signal eye_of_truth_changed(active: bool, remaining_seconds: float)

var current_scene: Node
var _eye_of_truth_remaining_seconds := 0.0


func _process(delta: float) -> void:
    if _eye_of_truth_remaining_seconds <= 0.0:
        return
    var previous_remaining := _eye_of_truth_remaining_seconds
    _eye_of_truth_remaining_seconds = maxf(0.0, _eye_of_truth_remaining_seconds - maxf(delta, 0.0))
    if previous_remaining > 0.0 and _eye_of_truth_remaining_seconds <= 0.0:
        eye_of_truth_changed.emit(false, 0.0)


func set_current_scene(scene: Node) -> void:
    current_scene = scene


func change_to_scene(scene_path: String) -> Error:
    return get_tree().change_scene_to_file(scene_path)


func reload_prototype() -> Error:
    return change_to_scene(PROTOTYPE_SCENE_PATH)


func activate_eye_of_truth(duration_seconds: float = DEFAULT_EYE_OF_TRUTH_SECONDS) -> void:
    _eye_of_truth_remaining_seconds = maxf(duration_seconds, 0.0)
    eye_of_truth_changed.emit(is_eye_of_truth_active(), _eye_of_truth_remaining_seconds)


func clear_eye_of_truth() -> void:
    if _eye_of_truth_remaining_seconds <= 0.0:
        return
    _eye_of_truth_remaining_seconds = 0.0
    eye_of_truth_changed.emit(false, 0.0)


func is_eye_of_truth_active() -> bool:
    return _eye_of_truth_remaining_seconds > 0.0


func get_eye_of_truth_remaining_seconds() -> float:
    return _eye_of_truth_remaining_seconds
