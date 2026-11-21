extends RefCounted
class_name ProgressStore

## Persistent player progress, mirroring the original save data
## (skills.wdl Var_Info: LevelsExist[], BestScores[], LevelEnCours, NeverPlayed,
## volume sliders). Stored as a ConfigFile under user://.
##
## Level state follows the WDL LevelsExist/LevelsInfo values: 0 missing,
## 1 present but locked ("win the previous level first"), 2 playable.
## A fresh install (sammypolish.wdl MakeSAV) unlocks the first level of each
## category: 1 (tutorial), 17 (jump) and 33 (think).

const DEFAULT_SAVE_PATH := "user://progress.cfg"
const SAVE_VERSION := 1

const LEVEL_MISSING := 0
const LEVEL_LOCKED := 1
const LEVEL_PLAYABLE := 2

const DEFAULT_UNLOCKED_LEVELS: Array[int] = [1, 17, 33]
const DEFAULT_CURRENT_LEVEL := 1
const DEFAULT_VOLUME_PERCENT := 100.0

const SECTION_META := "meta"
const SECTION_LEVELS := "levels"
const SECTION_SCORES := "best_scores"
const SECTION_SESSION := "session"
const SECTION_OPTIONS := "options"

var save_path := DEFAULT_SAVE_PATH
var current_level := DEFAULT_CURRENT_LEVEL
var never_played := true
var music_volume_percent := DEFAULT_VOLUME_PERCENT
var sfx_volume_percent := DEFAULT_VOLUME_PERCENT

var _unlocked_levels: Dictionary = {}
var _best_scores: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	current_level = DEFAULT_CURRENT_LEVEL
	never_played = true
	music_volume_percent = DEFAULT_VOLUME_PERCENT
	sfx_volume_percent = DEFAULT_VOLUME_PERCENT
	_unlocked_levels.clear()
	_best_scores.clear()
	for level_number in DEFAULT_UNLOCKED_LEVELS:
		_unlocked_levels[level_number] = true


func load_from_disk() -> Error:
	reset()
	if not FileAccess.file_exists(save_path):
		return ERR_FILE_NOT_FOUND
	var config := ConfigFile.new()
	var err := config.load(save_path)
	if err != OK:
		return err
	for level_number: Variant in config.get_value(SECTION_LEVELS, "unlocked", PackedInt32Array()):
		_unlocked_levels[int(level_number)] = true
	if config.has_section(SECTION_SCORES):
		for key in config.get_section_keys(SECTION_SCORES):
			_best_scores[int(key)] = int(config.get_value(SECTION_SCORES, key, 0))
	current_level = int(config.get_value(SECTION_SESSION, "current_level", DEFAULT_CURRENT_LEVEL))
	never_played = bool(config.get_value(SECTION_SESSION, "never_played", true))
	music_volume_percent = clampf(float(config.get_value(SECTION_OPTIONS, "music_volume_percent", DEFAULT_VOLUME_PERCENT)), 0.0, 100.0)
	sfx_volume_percent = clampf(float(config.get_value(SECTION_OPTIONS, "sfx_volume_percent", DEFAULT_VOLUME_PERCENT)), 0.0, 100.0)
	return OK


func save_to_disk() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION_META, "version", SAVE_VERSION)
	var unlocked := PackedInt32Array()
	for level_number: int in _unlocked_levels.keys():
		unlocked.append(level_number)
	unlocked.sort()
	config.set_value(SECTION_LEVELS, "unlocked", unlocked)
	var score_levels: Array = _best_scores.keys()
	score_levels.sort()
	for level_number: Variant in score_levels:
		config.set_value(SECTION_SCORES, str(level_number), int(_best_scores[level_number]))
	config.set_value(SECTION_SESSION, "current_level", current_level)
	config.set_value(SECTION_SESSION, "never_played", never_played)
	config.set_value(SECTION_OPTIONS, "music_volume_percent", music_volume_percent)
	config.set_value(SECTION_OPTIONS, "sfx_volume_percent", sfx_volume_percent)
	return config.save(save_path)


func is_level_unlocked(level_number: int) -> bool:
	return _unlocked_levels.has(level_number)


func unlock_level(level_number: int) -> void:
	if level_number > 0:
		_unlocked_levels[level_number] = true


func get_unlocked_levels() -> PackedInt32Array:
	var unlocked := PackedInt32Array()
	for level_number: int in _unlocked_levels.keys():
		unlocked.append(level_number)
	unlocked.sort()
	return unlocked


func level_state(level_number: int, available: bool) -> int:
	if not available:
		return LEVEL_MISSING
	return LEVEL_PLAYABLE if is_level_unlocked(level_number) else LEVEL_LOCKED


func get_best_score(level_number: int) -> int:
	return int(_best_scores.get(level_number, 0))


## InitLvl.wdl StoreBestScore: keeps the score only when it beats the record.
func record_score(level_number: int, score: int) -> bool:
	if level_number <= 0 or score <= get_best_score(level_number):
		return false
	_best_scores[level_number] = score
	return true
