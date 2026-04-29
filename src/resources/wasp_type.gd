extends Resource
class_name WaspType

@export var id: StringName = &""
@export var display_name: String = ""
@export var wdl_type_id: int = 0
@export var skin_index: int = 0
@export var visual_scale: float = 1.0
@export var damage: int = 1
@export var wdl_speed_units: float = 100.0
@export var speed: float = 14.0
@export var lifetime_seconds: float = 8.0
@export var homing: bool = false
@export var homing_scan_range: float = 0.0
@export var homing_turn_speed_degrees: float = 0.0
@export var homing_pitch_speed_degrees: float = 0.0
@export var multi_shot_count: int = 1
@export var multi_shot_spread_degrees: float = 0.0
@export var multi_shot_interval_seconds: float = 0.0
@export var fire_animation_speed: float = 1.0
@export var dive_arc: bool = false
@export var dive_rise_seconds: float = 0.0
@export var dive_hold_seconds: float = 0.0
@export var dive_level_seconds: float = 0.0
@export var dive_pitch_up_degrees_per_second: float = 0.0
@export var dive_pitch_down_degrees_per_second: float = 0.0
@export var camera_follow: bool = false
