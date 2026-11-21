extends Node

const KEY_DIAMOND_RULES_SCRIPT := preload("res://src/resources/key_diamond_rules.gd")
const MENU_LEVEL_CATALOG_SCRIPT := preload("res://src/menu/menu_level_catalog.gd")
const PROGRESS_STORE_SCRIPT := preload("res://src/core/progress_store.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/menu/main_menu.tscn"
const PROTOTYPE_SCENE_PATH := "res://scenes/prototype/prototype_world.tscn"
const DEFAULT_EYE_OF_TRUTH_SECONDS := 256.0 / 16.0
const EYE_OF_TRUTH_PANEL_MIN_SCALE := 0.02
const EYE_OF_TRUTH_SHRINK_SECONDS := (1.0 - EYE_OF_TRUTH_PANEL_MIN_SCALE) / 0.005 / 16.0
const SCORE_GOAL_REACH_SOUND_ASSET_ID := "sfx.score_reach"
## mm1.wdl: after the last level of a category (PreviousLevel 12/28/44) the
## game returns to the main menu instead of loading the next level.
const CATEGORY_LAST_LEVELS: Array[int] = [12, 28, 44]
const MAX_LEVEL_NUMBER := 48
const UNLOCK_ALL_LEVELS_SETTING := "sammy/debug/unlock_all_levels"
const CHEAT_BEEP_SOUND_ASSET_ID := "sfx.beep1"

signal eye_of_truth_changed(active: bool, remaining_seconds: float)
signal menu_level_selected(level_number: int, source_wmb: String, category_key: StringName)
signal score_changed(total_points: int, delta_points: int)
signal score_goal_changed(goal_points: int, start_points: int)
signal score_goal_reached(total_points: int, goal_points: int)
signal level_progress_changed()
signal score_goal_warning_requested()

var current_scene: Node
var scene_router: Node
var _eye_of_truth_remaining_seconds := 0.0
var _eye_of_truth_shrink_remaining_seconds := 0.0
var _score_points := 0
var _last_score_delta := 0
var _score_goal_points := 0
var _score_start_points := 0
var _score_goal_reward_granted := false
var _selected_menu_level_number := 0
var _selected_menu_level_source_wmb := ""
var _selected_menu_level_category: StringName = &""
var _current_level_number := 0
var _current_level_scene_path := ""
var progress: RefCounted = PROGRESS_STORE_SCRIPT.new()
var _all_levels_cheat_active := false
var _music_order: Dictionary = {}


func _ready() -> void:
    load_progress()
    _roll_music_order()
    call_deferred("_apply_saved_audio_options")


## mm1.wdl On_L ActivateAllLevels: Shift+V+L unlocks every level for the session.
func _unhandled_input(event: InputEvent) -> void:
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_L:
        return
    if Input.is_physical_key_pressed(KEY_SHIFT) and Input.is_physical_key_pressed(KEY_V):
        unlock_all_levels_for_session()


func _process(delta: float) -> void:
    _update_eye_of_truth(maxf(delta, 0.0))


## mm1.wdl ReduitEyePanel: DureeEyeTruth counts down first, then the panel
## shrinks (scale -0.005/tick down to 0.02); EyeOfTruth stays on until then.
func _update_eye_of_truth(delta: float) -> void:
    if not is_eye_of_truth_active():
        return
    var step := delta
    if _eye_of_truth_remaining_seconds > 0.0:
        var used := minf(step, _eye_of_truth_remaining_seconds)
        _eye_of_truth_remaining_seconds -= used
        step -= used
    if _eye_of_truth_remaining_seconds <= 0.0 and step > 0.0:
        _eye_of_truth_shrink_remaining_seconds = maxf(0.0, _eye_of_truth_shrink_remaining_seconds - step)
    if not is_eye_of_truth_active():
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
    _current_level_number = 0
    _current_level_scene_path = ""
    var route_err := _try_scene_router(&"show_prototype_world")
    if route_err != ERR_UNAVAILABLE:
        return route_err
    return change_to_scene(PROTOTYPE_SCENE_PATH)


func reload_prototype() -> Error:
    return show_prototype_world()


## Loads a level baked from its original WMB (see tools/build_level_scenes.gd).
## Only available (baked) and unlocked levels can be loaded.
func show_level(level_number: int) -> Error:
    var level_data := get_level_entry(level_number)
    if level_data.is_empty() or not bool(level_data.get("available", false)):
        return ERR_DOES_NOT_EXIST
    if not bool(level_data.get("unlocked", false)):
        return ERR_UNAUTHORIZED
    _current_level_number = level_number
    _current_level_scene_path = String(level_data["scene_path"])
    progress.current_level = level_number
    progress.never_played = false
    save_progress()
    return _show_level_scene(_current_level_scene_path)


## Menu "Play": resumes the saved current level (WDL LevelEnCours).
func play_current_level() -> Error:
    var level_number := int(progress.current_level)
    if show_level(level_number) == OK:
        return OK
    return show_level(PROGRESS_STORE_SCRIPT.DEFAULT_CURRENT_LEVEL)


## Exit tile reached (mm1.wdl PartieGagnee): store the best score, unlock this
## and the next existing level (InitLvl.wdl ValideLevel/SearchNextLevel), then
## load the next level, or return to the menu after a category's last level.
func complete_current_level() -> Error:
    var level_number := _current_level_number
    if level_number <= 0:
        return show_main_menu()
    progress.record_score(level_number, _score_points)
    progress.unlock_level(level_number)
    var next_level := find_next_available_level(level_number)
    if next_level > 0:
        progress.unlock_level(next_level)
        progress.current_level = next_level
    save_progress()
    level_progress_changed.emit()
    if next_level <= 0 or CATEGORY_LAST_LEVELS.has(level_number):
        clear_current_level()
        return show_main_menu()
    return show_level(next_level)


## Lives exhausted, R pressed, or pause Restart (mm1.wdl: BallesJoueur1 <= 0):
## store the best score and reload the same level.
func fail_current_level() -> Error:
    if _current_level_number <= 0:
        return reload_prototype()
    progress.record_score(_current_level_number, _score_points)
    save_progress()
    return reload_current_level()


func clear_current_level() -> void:
    _current_level_number = 0
    _current_level_scene_path = ""


## InitLvl.wdl SearchNextLevel: the first later level that exists.
func find_next_available_level(level_number: int) -> int:
    for candidate in range(level_number + 1, MAX_LEVEL_NUMBER + 1):
        var entry: Dictionary = MENU_LEVEL_CATALOG_SCRIPT.level_by_number(candidate)
        if not entry.is_empty() and bool(entry.get("available", false)):
            return candidate
    return 0


## Catalog entry plus progress: `available` (baked), `unlocked`, `selectable`
## (both), `best_score`.
func get_level_entry(level_number: int) -> Dictionary:
    var entry: Dictionary = MENU_LEVEL_CATALOG_SCRIPT.level_by_number(level_number)
    return decorate_level_entry(entry)


func decorate_level_entry(level_data: Dictionary) -> Dictionary:
    if level_data.is_empty():
        return level_data
    var entry := level_data.duplicate(true)
    var level_number := int(entry.get("level_number", 0))
    var available := bool(entry.get("available", false))
    var unlocked := is_level_unlocked(level_number)
    entry["unlocked"] = unlocked
    entry["selectable"] = available and unlocked
    entry["best_score"] = int(progress.get_best_score(level_number))
    return entry


func is_level_unlocked(level_number: int) -> bool:
    if _all_levels_cheat_active or bool(ProjectSettings.get_setting(UNLOCK_ALL_LEVELS_SETTING, false)):
        return true
    return bool(progress.is_level_unlocked(level_number))


func unlock_all_levels_for_session() -> void:
    _all_levels_cheat_active = true
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", CHEAT_BEEP_SOUND_ASSET_ID)
    level_progress_changed.emit()


func is_all_levels_cheat_active() -> bool:
    return _all_levels_cheat_active


## mm1.wdl: a white exit door (Skill6 == 7) touched below ScoreGoal calls
## WarnScoreGoal, which blinks the score-to-reach panel.
func request_score_goal_warning() -> void:
    if _score_goal_points > 0 and _score_points < _score_goal_points:
        score_goal_warning_requested.emit()


func get_progress() -> RefCounted:
    return progress


func load_progress() -> Error:
    var err := int(progress.load_from_disk())
    level_progress_changed.emit()
    return err


func save_progress() -> Error:
    return progress.save_to_disk()


## Points the progress store at another file (tests) and optionally resets it.
func use_progress_save_path(save_path: String, reset_progress: bool = true) -> void:
    progress.save_path = save_path
    if reset_progress:
        progress.reset()
        _all_levels_cheat_active = false
    else:
        progress.load_from_disk()
    level_progress_changed.emit()


func record_audio_options(music_volume_percent: float, sfx_volume_percent: float) -> void:
    progress.music_volume_percent = clampf(music_volume_percent, 0.0, 100.0)
    progress.sfx_volume_percent = clampf(sfx_volume_percent, 0.0, 100.0)
    save_progress()


func _apply_saved_audio_options() -> void:
    var audio := get_node_or_null("/root/Audio")
    if audio == null:
        return
    if audio.has_method("set_music_volume_percent"):
        audio.call("set_music_volume_percent", float(progress.music_volume_percent))
    if audio.has_method("set_sfx_volume_percent"):
        audio.call("set_sfx_volume_percent", float(progress.sfx_volume_percent))


## sammypolish.wdl MusicOrder: re-rolled every launch. Tutorials alternate
## tracks 1/2, levels 17-20 and 33-36 pick 1-3, everything else 1-8.
func _roll_music_order() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    _music_order.clear()
    for level_number in range(1, MAX_LEVEL_NUMBER + 1):
        if level_number <= 12:
            _music_order[level_number] = 1 if level_number % 2 == 1 else 2
        elif (level_number >= 17 and level_number <= 20) or (level_number >= 33 and level_number <= 36):
            _music_order[level_number] = rng.randi_range(1, 3)
        else:
            _music_order[level_number] = rng.randi_range(1, 8)


## sons.wdl musique1..9: tracks 1-7 are sammy01-07, 8 and 9 reuse 01 and 02.
func get_music_asset_id_for_level(level_number: int) -> String:
    var track := int(_music_order.get(level_number, 1))
    if track == 8:
        track = 1
    elif track == 9:
        track = 2
    return "music.sammy%02d" % clampi(track, 1, 7)


## Restarts the level that is currently loaded, or the prototype when none is.
func reload_current_level() -> Error:
    if _current_level_scene_path.is_empty():
        return reload_prototype()
    return _show_level_scene(_current_level_scene_path)


func get_current_level_number() -> int:
    return _current_level_number


func get_current_level_scene_path() -> String:
    return _current_level_scene_path


func _show_level_scene(scene_path: String) -> Error:
    var route_err := _try_scene_router(&"show_scene", [scene_path])
    if route_err != ERR_UNAVAILABLE:
        return route_err
    return change_to_scene(scene_path)


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


func _try_scene_router(method_name: StringName, args: Array = []) -> Error:
    if scene_router == null or not is_instance_valid(scene_router):
        return ERR_UNAVAILABLE
    if not scene_router.has_method(method_name):
        return ERR_UNAVAILABLE

    var result = scene_router.callv(method_name, args)
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
    if duration_seconds <= 0.0:
        clear_eye_of_truth()
        return
    _eye_of_truth_remaining_seconds = duration_seconds
    _eye_of_truth_shrink_remaining_seconds = EYE_OF_TRUTH_SHRINK_SECONDS
    eye_of_truth_changed.emit(is_eye_of_truth_active(), _eye_of_truth_remaining_seconds)


func clear_eye_of_truth() -> void:
    if not is_eye_of_truth_active():
        return
    _eye_of_truth_remaining_seconds = 0.0
    _eye_of_truth_shrink_remaining_seconds = 0.0
    eye_of_truth_changed.emit(false, 0.0)


func is_eye_of_truth_active() -> bool:
    return _eye_of_truth_remaining_seconds > 0.0 or _eye_of_truth_shrink_remaining_seconds > 0.0


## PanEye scale: 1 while DureeEyeTruth runs, then shrinking towards 0.02.
func get_eye_of_truth_panel_scale() -> float:
    if not is_eye_of_truth_active():
        return 0.0
    if _eye_of_truth_remaining_seconds > 0.0:
        return 1.0
    return EYE_OF_TRUTH_PANEL_MIN_SCALE + (1.0 - EYE_OF_TRUTH_PANEL_MIN_SCALE) * (_eye_of_truth_shrink_remaining_seconds / EYE_OF_TRUTH_SHRINK_SECONDS)


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
