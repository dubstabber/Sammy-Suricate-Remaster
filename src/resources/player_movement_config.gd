extends Resource
class_name PlayerMovementConfig

@export var walk_speed: float = 5.2
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var jump_velocity: float = 7.5
@export var jump_forward_speed: float = 1.0
@export var jump_air_control_multiplier: float = 0.75
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
@export var low_step_height: float = 0.22

# Original WDL level physics (applied by level worlds through
# PlayerController.apply_wdl_level_physics; the defaults keep the prototype
# behaviour unchanged).
## Vertical speed when walking off a ledge (WDL Gravite); 0 keeps the current speed.
@export var fall_start_velocity: float = 0.0
## Fall acceleration when not jumping (WDL AccGravite); 0 uses `gravity`.
@export var fall_gravity: float = 0.0
## player.wdl handlePente slope sliding.
@export var slope_sliding_enabled: bool = false
## Slide when the floor normal's up component is at most this (WDL SlopeAngleMin).
@export var slope_normal_max_y: float = 0.92
## WDL Accpente: slide build-up per tick, scaled by (1 - normal.y).
@export var slope_acceleration: float = 1.5
## WDL ForcePente: slide speed cap per unit of horizontal normal, quants/tick.
@export var slope_force: float = 100.0
## WDL AmortiPenteEnd: slide friction per tick once off the slope.
@export var slope_end_damping: float = 0.3
## WDL BigSlope / MediumSlope slide speeds (quants/tick) that restrict control.
@export var slope_big: float = 10.0
@export var slope_medium: float = 2.0
## WDL PlayerJump needs the floor straight under Sammy (no jumping off edges).
@export var jump_requires_center_floor: bool = false
@export var jump_center_floor_max_distance: float = 0.15
