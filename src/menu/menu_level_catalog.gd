extends RefCounted

const CATEGORY_TUTORIAL := &"tutorial"
const CATEGORY_JUMP := &"jump"
const CATEGORY_THINK := &"think"
const CATEGORY_BONUS := &"bonus"

const CATEGORY_TITLES := {
	CATEGORY_TUTORIAL: "Tutorial Levels",
	CATEGORY_JUMP: "Jump Levels",
	CATEGORY_THINK: "Think Levels",
	CATEGORY_BONUS: "Bonus Levels"
}

const LEVELS := [
	{"level_number": 1, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 1", "source_wmb": "10001.WMB"},
	{"level_number": 2, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 2", "source_wmb": "10002.WMB"},
	{"level_number": 3, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 3", "source_wmb": "10003.WMB"},
	{"level_number": 4, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 4", "source_wmb": "10004.WMB"},
	{"level_number": 5, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 5", "source_wmb": "10005.WMB"},
	{"level_number": 6, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 6", "source_wmb": "10006.WMB"},
	{"level_number": 7, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 7", "source_wmb": "10007.WMB"},
	{"level_number": 8, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 8", "source_wmb": "10008.WMB"},
	{"level_number": 9, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 9", "source_wmb": "10009.WMB"},
	{"level_number": 10, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 10", "source_wmb": "10012.WMB"},
	{"level_number": 11, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 11", "source_wmb": "10010.WMB"},
	{"level_number": 12, "category": CATEGORY_TUTORIAL, "display_name": "Szkolenie 12", "source_wmb": "10011.WMB"},
	{"level_number": 13, "category": CATEGORY_BONUS, "display_name": "Bonus 1", "source_wmb": "bonus1.WMB"},
	{"level_number": 14, "category": CATEGORY_BONUS, "display_name": "Bonus 2", "source_wmb": "bonus2.WMB"},
	{"level_number": 15, "category": CATEGORY_BONUS, "display_name": "Bonus 3", "source_wmb": "bonus3.WMB"},
	{"level_number": 16, "category": CATEGORY_BONUS, "display_name": "Bonus 4", "source_wmb": "bonus4.WMB"},
	{"level_number": 17, "category": CATEGORY_JUMP, "display_name": "Jump 1", "source_wmb": "101o_j.WMB"},
	{"level_number": 18, "category": CATEGORY_JUMP, "display_name": "Jump 2", "source_wmb": "104m_j.WMB"},
	{"level_number": 19, "category": CATEGORY_JUMP, "display_name": "Jump 3", "source_wmb": "103j_j.WMB"},
	{"level_number": 20, "category": CATEGORY_JUMP, "display_name": "Jump 4", "source_wmb": "112e_j.WMB"},
	{"level_number": 21, "category": CATEGORY_JUMP, "display_name": "Jump 5", "source_wmb": "107i_j.WMB"},
	{"level_number": 22, "category": CATEGORY_JUMP, "display_name": "Jump 6", "source_wmb": "174a_j07.WMB"},
	{"level_number": 23, "category": CATEGORY_JUMP, "display_name": "Jump 7", "source_wmb": "111r_j.WMB"},
	{"level_number": 24, "category": CATEGORY_JUMP, "display_name": "Jump 8", "source_wmb": "172c_j06.WMB"},
	{"level_number": 25, "category": CATEGORY_JUMP, "display_name": "Jump 9", "source_wmb": "175c_t.WMB"},
	{"level_number": 26, "category": CATEGORY_JUMP, "display_name": "Jump 10", "source_wmb": "177e_j.WMB"},
	{"level_number": 27, "category": CATEGORY_JUMP, "display_name": "Jump 11", "source_wmb": "108i_j.WMB"},
	{"level_number": 28, "category": CATEGORY_JUMP, "display_name": "Jump 12", "source_wmb": "179f_t.WMB"},
	{"level_number": 29, "category": CATEGORY_BONUS, "display_name": "Bonus 5", "source_wmb": "bonus5.WMB"},
	{"level_number": 30, "category": CATEGORY_BONUS, "display_name": "Bonus 6", "source_wmb": "bonus6.WMB"},
	{"level_number": 31, "category": CATEGORY_BONUS, "display_name": "Bonus 7", "source_wmb": "bonus7.WMB"},
	{"level_number": 32, "category": CATEGORY_BONUS, "display_name": "Bonus 8", "source_wmb": "bonus8.WMB"},
	{"level_number": 33, "category": CATEGORY_THINK, "display_name": "Think 1", "source_wmb": "106g_t.WMB"},
	{"level_number": 34, "category": CATEGORY_THINK, "display_name": "Think 2", "source_wmb": "171c_t04.WMB"},
	{"level_number": 35, "category": CATEGORY_THINK, "display_name": "Think 3", "source_wmb": "110n_t.WMB"},
	{"level_number": 36, "category": CATEGORY_THINK, "display_name": "Think 4", "source_wmb": "180c_t.WMB"},
	{"level_number": 37, "category": CATEGORY_THINK, "display_name": "Think 5", "source_wmb": "170b_t00.WMB"},
	{"level_number": 38, "category": CATEGORY_THINK, "display_name": "Think 6", "source_wmb": "102n_t.WMB"},
	{"level_number": 39, "category": CATEGORY_THINK, "display_name": "Think 7", "source_wmb": "173B_t05.WMB"},
	{"level_number": 40, "category": CATEGORY_THINK, "display_name": "Think 8", "source_wmb": "114t_t.WMB"},
	{"level_number": 41, "category": CATEGORY_THINK, "display_name": "Think 9", "source_wmb": "178d_t.WMB"},
	{"level_number": 42, "category": CATEGORY_THINK, "display_name": "Think 10", "source_wmb": "176g_t.WMB"},
	{"level_number": 43, "category": CATEGORY_THINK, "display_name": "Think 11", "source_wmb": "113q_t.WMB"},
	{"level_number": 44, "category": CATEGORY_THINK, "display_name": "Think 12", "source_wmb": "109o_t.WMB"},
	{"level_number": 45, "category": CATEGORY_BONUS, "display_name": "Bonus 9", "source_wmb": "bonus9.WMB"},
	{"level_number": 46, "category": CATEGORY_BONUS, "display_name": "Bonus 10", "source_wmb": "bonus10.WMB"},
	{"level_number": 47, "category": CATEGORY_BONUS, "display_name": "Bonus 11", "source_wmb": "bonus11.WMB"},
	{"level_number": 48, "category": CATEGORY_BONUS, "display_name": "Bonus 12", "source_wmb": "bonus12.WMB"},
]


static func title_for_category(category_key: StringName) -> String:
	return String(CATEGORY_TITLES.get(category_key, "Levels"))


static func levels_for_category(category_key: StringName) -> Array[Dictionary]:
	var category_levels: Array[Dictionary] = []
	for level_data: Dictionary in LEVELS:
		if StringName(level_data["category"]) == category_key:
			category_levels.append(_with_runtime_fields(level_data))
	return category_levels


static func level_by_number(level_number: int) -> Dictionary:
	for level_data: Dictionary in LEVELS:
		if int(level_data["level_number"]) == level_number:
			return _with_runtime_fields(level_data)
	return {}


static func has_category(category_key: StringName) -> bool:
	return CATEGORY_TITLES.has(category_key)


static func _with_runtime_fields(level_data: Dictionary) -> Dictionary:
	var result := level_data.duplicate(true)
	var level_number := int(result["level_number"])
	result["action_id"] = 100 + level_number
	result["source"] = "Loads.wdl:InitLevel%d" % level_number
	result["selectable"] = true
	return result
