extends Node

const KEY_DIAMOND_RULES_SCRIPT := preload("res://src/resources/key_diamond_rules.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/menu/main_menu.tscn"
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"
const DEFAULT_EYE_OF_TRUTH_SECONDS := 256.0 / 16.0
const SCORE_GOAL_REACH_SOUND_ASSET_ID := "sfx.score_reach"

signal eye_of_truth_changed(active: bool, remaining_seconds: float)
signal menu_level_selected(level_number: int, source_wmb: String, category_key: StringName)
signal score_changed(total_points: int, delta_points: int)
signal score_goal_changed(goal_points: int, start_points: int)
signal score_goal_reached(total_points: int, goal_points: int)

var current_scene: Node
var scene_router: Node
var _eye_of_truth_remaining_seconds := 0.0
var _score_points := 0
var _last_score_delta := 0
var _score_goal_points := 0
var _score_start_points := 0
var _score_goal_reward_granted := false
var _selected_menu_level_number := 0
var _selected_menu_level_source_wmb := ""
var _selected_menu_level_category: StringName = &""


func _process(delta: float) -> void:
    if _eye_of_truth_remaining_seconds <= 0.0:
        return
    var previous_remaining := _eye_of_truth_remaining_seconds
    _eye_of_truth_remaining_seconds = maxf(0.0, _eye_of_truth_remaining_seconds - maxf(delta, 0.0))
    if previous_remaining > 0.0 and _eye_of_truth_remaining_seconds <= 0.0:
        eye_of_truth_changed.emit(false, 0.0)


func set_current_scene(scene: Node) -> void:
    current_scene = scene


func set_scene_router(router: Node) -> void:
    scene_router = router


func change_to_scene(scene_path: String) -> Error:
    return get_tree().change_scene_to_file(scene_path)


func show_main_menu() -> Error:
    var route_err := _try_scene_router(&"show_main_menu")
    if route_err != ERR_UNAVAILABLE:
        return route_err
    return change_to_scene(MAIN_SCENE_PATH)


func show_prototype_world() -> Error:
    var route_err := _try_scene_router(&"show_prototype_world")
    if route_err != ERR_UNAVAILABLE:
        return route_err
    return change_to_scene(PROTOTYPE_SCENE_PATH)


func reload_prototype() -> Error:
    return show_prototype_world()


func select_menu_level(level_number: int, source_wmb: String, category_key: StringName) -> void:
    _selected_menu_level_number = maxi(0, level_number)
    _selected_menu_level_source_wmb = source_wmb
    _selected_menu_level_category = category_key
    menu_level_selected.emit(_selected_menu_level_number, _selected_menu_level_source_wmb, _selected_menu_level_category)


func clear_selected_menu_level() -> void:
    _selected_menu_level_number = 0
    _selected_menu_level_source_wmb = ""
    _selected_menu_level_category = &""


func get_selected_menu_level_number() -> int:
    return _selected_menu_level_number


func get_selected_menu_level_source_wmb() -> String:
    return _selected_menu_level_source_wmb


func get_selected_menu_level_category() -> StringName:
    return _selected_menu_level_category


func get_selected_menu_level() -> Dictionary:
    return {
        "level_number": _selected_menu_level_number,
        "source_wmb": _selected_menu_level_source_wmb,
        "category": _selected_menu_level_category
    }


func _try_scene_router(method_name: StringName) -> Error:
    if scene_router == null or not is_instance_valid(scene_router):
        return ERR_UNAVAILABLE
    if not scene_router.has_method(method_name):
        return ERR_UNAVAILABLE

    var result = scene_router.call(method_name)
    if typeof(result) == TYPE_INT:
        return int(result)
    return OK


func add_points(delta_points: int) -> int:
    var previous_points := _score_points
    _score_points = maxi(0, _score_points + delta_points)
    _last_score_delta = _score_points - previous_points
    score_changed.emit(_score_points, _last_score_delta)
    _try_reach_score_goal(previous_points)
    return _last_score_delta


func clear_score() -> void:
    _score_points = _score_start_points
    _last_score_delta = 0
    _score_goal_reward_granted = false
    score_changed.emit(_score_points, _last_score_delta)


func get_score_points() -> int:
    return _score_points


func get_last_score_delta() -> int:
    return _last_score_delta


func configure_score_goal(goal_points: int, start_points: int = 0) -> void:
    _score_goal_points = maxi(0, goal_points)
    _score_start_points = maxi(0, start_points)
    score_goal_changed.emit(_score_goal_points, _score_start_points)
    clear_score()


func clear_score_goal() -> void:
    configure_score_goal(0, 0)


func get_score_goal_points() -> int:
    return _score_goal_points


func get_score_start_points() -> int:
    return _score_start_points


func is_score_goal_reached() -> bool:
    return _score_goal_points > 0 and _score_points >= _score_goal_points


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


func _try_reach_score_goal(previous_points: int) -> void:
    if _score_goal_points <= 0 or _score_goal_reward_granted:
        return
    if previous_points >= _score_goal_points or _score_points < _score_goal_points:
        return

    _score_goal_reward_granted = true
    _play_score_goal_sound()
    _grant_score_goal_key()
    score_goal_reached.emit(_score_points, _score_goal_points)


func _play_score_goal_sound() -> void:
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", SCORE_GOAL_REACH_SOUND_ASSET_ID)


func _grant_score_goal_key() -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return
    if player.has_method("grant_score_goal_key"):
        player.call("grant_score_goal_key")
    elif player.has_method("set_current_key_id"):
        player.call("set_current_key_id", KEY_DIAMOND_RULES_SCRIPT.KEY_ALL)
