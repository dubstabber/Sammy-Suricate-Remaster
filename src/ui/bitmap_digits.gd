extends Control
class_name BitmapDigits

## Draws a number with an original A5 digit font (fontes.wdl): one bitmap row
## of 11 glyphs "0123456789:". Like WDL `DIGITS x, y, len, font, factor, var`
## the value is drawn right-aligned in a `digit_count`-wide field.

const GLYPH_COUNT := 11

@export var font_texture: Texture2D:
	set(value):
		font_texture = value
		_update_size()
		queue_redraw()
@export var digit_count: int = 5:
	set(value):
		digit_count = maxi(value, 1)
		_update_size()
		queue_redraw()
@export var value: int = 0:
	set(new_value):
		if new_value == value:
			return
		value = new_value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()


func get_glyph_size() -> Vector2:
	if font_texture == null:
		return Vector2.ZERO
	return Vector2(floorf(float(font_texture.get_width()) / GLYPH_COUNT), float(font_texture.get_height()))


## Text as drawn (no leading zeros, clipped to the field width).
func get_display_text() -> String:
	var text := str(maxi(value, 0))
	return text.right(digit_count) if text.length() > digit_count else text


func _update_size() -> void:
	var glyph := get_glyph_size()
	custom_minimum_size = Vector2(glyph.x * digit_count, glyph.y)
	size = custom_minimum_size


func _draw() -> void:
	if font_texture == null:
		return
	var glyph := get_glyph_size()
	var text := get_display_text()
	var x := glyph.x * (digit_count - text.length())
	for character in text:
		var glyph_index := character.unicode_at(0) - "0".unicode_at(0)
		if glyph_index < 0 or glyph_index > 9:
			glyph_index = GLYPH_COUNT - 1
		draw_texture_rect_region(font_texture, Rect2(Vector2(x, 0.0), glyph), Rect2(Vector2(glyph.x * glyph_index, 0.0), glyph))
		x += glyph.x
