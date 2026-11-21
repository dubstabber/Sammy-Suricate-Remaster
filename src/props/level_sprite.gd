@tool
extends Sprite3D
class_name LevelSprite

## Standalone level sprite (WDL InitArbre/OnGround grass, trees, ...).
## Without WDL Flag1 the original sprites are vertical planes oriented by pan
## (levels cross two of them at pan 1/90); Flag1 makes them face the camera.

@export var camera_facing: bool = false:
	set(value):
		camera_facing = value
		_apply_sprite_settings()


func _ready() -> void:
	_apply_sprite_settings()


func _apply_sprite_settings() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if camera_facing else BaseMaterial3D.BILLBOARD_DISABLED
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	double_sided = true
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
