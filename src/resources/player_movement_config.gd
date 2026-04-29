extends Resource
class_name PlayerMovementConfig

@export var walk_speed: float = 5.2
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 22.0
@export var turn_speed_degrees: float = 180.0
@export var moving_turn_speed_degrees: float = 126.0
@export var quick_turn_time_units_per_second: float = 16.0
@export var quick_turn_initial_speed_factor: float = 0.25
@export var quick_turn_followup_speed_factor: float = 0.4
@export var quick_turn_stop_speed_degrees: float = 2.0
@export var quick_turn_animation_speed_multiplier: float = 2.0
@export var boost_speed_multiplier: float = 2.0
@export var boost_turn_multiplier: float = 0.75
@export var boost_capacity_max: float = 150.0
@export var boost_initial_capacity: float = 0.0
@export var boost_pickup_capacity: float = 150.0
@export var boost_consumption_per_second: float = 16.0
@export var animation_blend_seconds: float = 0.18
@export var walk_stop_blend_seconds: float = 0.35
@export var walk_animation_speed_multiplier: float = 1.75
@export var minimum_walk_animation_speed: float = 0.25
@export var visual_scale_multiplier: float = 1.0
