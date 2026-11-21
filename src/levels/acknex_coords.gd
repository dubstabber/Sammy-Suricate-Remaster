extends RefCounted
class_name AcknexCoords

## Acknex (x, y, z-up, quants) to Godot (x, y-up, -z, meters) conversion.
##
## Acknex pan is counter-clockwise from +X seen from above. A Godot yaw of +pan
## maps +X onto the Acknex pan direction, so props use yaw = pan. Character
## nodes face Godot -Z (models are rotated in `Assets`), so their yaw is
## pan - 90 to make them face the same direction.

const SCALE := 0.01
const CHARACTER_YAW_OFFSET_DEGREES := -90.0


static func to_godot_position(acknex: Vector3) -> Vector3:
	return Vector3(acknex.x, acknex.z, -acknex.y) * SCALE


static func array_to_vector3(values: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if values is Array and (values as Array).size() >= 3:
		var array := values as Array
		return Vector3(float(array[0]), float(array[1]), float(array[2]))
	return fallback


static func prop_yaw_degrees(pan_degrees: float) -> float:
	return wrapf(pan_degrees, -180.0, 180.0)


static func character_yaw_degrees(pan_degrees: float) -> float:
	return wrapf(pan_degrees + CHARACTER_YAW_OFFSET_DEGREES, -180.0, 180.0)


static func prop_basis(pan_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(prop_yaw_degrees(pan_degrees)))


static func character_basis(pan_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(character_yaw_degrees(pan_degrees)))


## Direction an Acknex pan angle points at, in Godot space.
static func pan_direction(pan_degrees: float) -> Vector3:
	var radians := deg_to_rad(pan_degrees)
	return Vector3(cos(radians), 0.0, -sin(radians))
