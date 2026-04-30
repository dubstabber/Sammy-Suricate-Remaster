extends RefCounted
class_name KeyDiamondRules

const KEY_NONE := 0
const KEY_RED := 1
const KEY_YELLOW := 2
const KEY_ORANGE := 3
const KEY_BLUE := 4
const KEY_MAGENTA := 5
const KEY_GREEN := 6
const KEY_ALL := 255

const VISUAL_FRAME_COUNT := 17
const PANEL_SLOT_WIDTH := 42


static func is_valid_key_id(key_id: int) -> bool:
	return key_id == KEY_ALL or (key_id >= KEY_RED and key_id <= KEY_GREEN)


static func is_primary_key(key_id: int) -> bool:
	return key_id == KEY_RED or key_id == KEY_YELLOW or key_id == KEY_BLUE


static func mix_keys(first_key_id: int, second_key_id: int) -> int:
	var low := mini(first_key_id, second_key_id)
	var high := maxi(first_key_id, second_key_id)
	if low == KEY_RED and high == KEY_YELLOW:
		return KEY_ORANGE
	if low == KEY_RED and high == KEY_BLUE:
		return KEY_MAGENTA
	if low == KEY_YELLOW and high == KEY_BLUE:
		return KEY_GREEN
	return KEY_NONE


static func can_open_gate(player_key_id: int, required_key_id: int, strict_match: bool = false) -> bool:
	if required_key_id == KEY_NONE:
		return true
	if player_key_id == KEY_ALL:
		return true
	if player_key_id == required_key_id:
		return true
	if strict_match:
		return false
	# mm1.wdl allows exact mixed keys, or a single primary color that is part of the required mix.
	return is_primary_key(player_key_id) and ((player_key_id & required_key_id) != 0)


static func key_name(key_id: int) -> String:
	match key_id:
		KEY_RED:
			return "Red"
		KEY_YELLOW:
			return "Yellow"
		KEY_ORANGE:
			return "Orange"
		KEY_BLUE:
			return "Blue"
		KEY_MAGENTA:
			return "Magenta"
		KEY_GREEN:
			return "Green"
		KEY_ALL:
			return "All"
	return "None"


static func key_color(key_id: int) -> Color:
	match key_id:
		KEY_RED:
			return Color(1.0, 0.1, 0.08, 1.0)
		KEY_YELLOW:
			return Color(1.0, 0.9, 0.08, 1.0)
		KEY_ORANGE:
			return Color(1.0, 0.45, 0.05, 1.0)
		KEY_BLUE:
			return Color(0.12, 0.36, 1.0, 1.0)
		KEY_MAGENTA:
			return Color(1.0, 0.1, 0.95, 1.0)
		KEY_GREEN:
			return Color(0.1, 0.95, 0.18, 1.0)
		KEY_ALL:
			return Color(0.9, 0.9, 0.9, 1.0)
	return Color.WHITE


static func key_texture_asset_id(key_id: int) -> String:
	match key_id:
		KEY_RED:
			return "texture.key_diamond.red"
		KEY_YELLOW:
			return "texture.key_diamond.yellow"
		KEY_ORANGE:
			return "texture.key_diamond.orange"
		KEY_BLUE:
			return "texture.key_diamond.blue"
		KEY_MAGENTA:
			return "texture.key_diamond.magenta"
		KEY_GREEN:
			return "texture.key_diamond.green"
		KEY_ALL:
			return "texture.key_diamond.multi"
	return ""


static func key_resource_path(key_id: int) -> String:
	match key_id:
		KEY_RED:
			return "res://assets/key_diamonds/red.tres"
		KEY_YELLOW:
			return "res://assets/key_diamonds/yellow.tres"
		KEY_ORANGE:
			return "res://assets/key_diamonds/orange.tres"
		KEY_BLUE:
			return "res://assets/key_diamonds/blue.tres"
		KEY_MAGENTA:
			return "res://assets/key_diamonds/magenta.tres"
		KEY_GREEN:
			return "res://assets/key_diamonds/green.tres"
		KEY_ALL:
			return "res://assets/key_diamonds/all.tres"
	return ""


static func panel_slot(key_id: int) -> int:
	if key_id == KEY_ALL:
		return 7
	if key_id >= KEY_RED and key_id <= KEY_GREEN:
		return key_id
	return 0
