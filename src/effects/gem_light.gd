extends OmniLight3D
class_name GemLight

## gems.wdl GemLight: a coloured dynamic light that starts at lightrange 300
## and shrinks 15 quants per tick until it drops below 100. V is a key id
## (1 red, 2 yellow, 3 orange, 4 blue, 5 magenta, 6 green, 7 white wasp).

const START_RANGE_UNITS := 300.0
const END_RANGE_UNITS := 100.0
const SHRINK_UNITS_PER_TICK := 15.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const TICKS_PER_SECOND := 16.0
const COLORS := {
	1: Color8(250, 0, 0),
	2: Color8(250, 250, 0),
	3: Color8(250, 100, 0),
	4: Color8(0, 0, 250),
	5: Color8(250, 0, 250),
	6: Color8(0, 250, 0),
	7: Color8(150, 150, 150),
}

var _range_units := START_RANGE_UNITS


## Attaches a GemLight to `owner_node` unless one is already running there
## (WDL skips the flash while My.lightRange is non-zero).
static func flash(owner_node: Node3D, color_id: int) -> Node:
	if owner_node == null or not owner_node.is_inside_tree():
		return null
	for child in owner_node.get_children():
		if child.has_meta(&"gem_light"):
			return child
	var light := (load("res://src/effects/gem_light.gd") as GDScript).new() as OmniLight3D
	light.set_meta(&"gem_light", true)
	light.name = "GemLight"
	light.light_color = COLORS.get(color_id, Color8(0, 0, 0))
	owner_node.add_child(light)
	return light


func _ready() -> void:
	shadow_enabled = false
	_apply_range()


func _process(delta: float) -> void:
	_range_units -= SHRINK_UNITS_PER_TICK * TICKS_PER_SECOND * maxf(delta, 0.0)
	if _range_units <= END_RANGE_UNITS:
		queue_free()
		return
	_apply_range()


func _apply_range() -> void:
	omni_range = _range_units * ACKNEX_TO_GODOT_SCALE
