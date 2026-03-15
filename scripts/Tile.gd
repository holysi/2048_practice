# scripts/Tile.gd
class_name Tile
extends Panel

@onready var value_label: Label = $ValueLabel

var theme_res: TileTheme
var value: int = 0:
	set(v):
		value = v
		_update_display()

func setup(tile_theme: TileTheme) -> void:
	theme_res = tile_theme
	_update_display()

func _update_display() -> void:
	if theme_res == null:
		return
	if value == 0:
		visible = false
		return
	visible = true
	value_label.text = str(value)
	value_label.add_theme_color_override("font_color", theme_res.get_text_color(value))
	var style = StyleBoxFlat.new()
	style.bg_color = theme_res.get_tile_color(value)
	style.corner_radius_top_left = int(theme_res.tile_corner_radius)
	style.corner_radius_top_right = int(theme_res.tile_corner_radius)
	style.corner_radius_bottom_left = int(theme_res.tile_corner_radius)
	style.corner_radius_bottom_right = int(theme_res.tile_corner_radius)
	add_theme_stylebox_override("panel", style)

var _anim_tween: Tween = null

func animate_spawn() -> void:
	_kill_tween()
	pivot_offset = size / 2
	scale = Vector2.ZERO
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.12)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)

func animate_merge(merged_value: int) -> void:
	_kill_tween()
	pivot_offset = size / 2
	var intensity: float = log(float(merged_value)) / log(2048.0)
	var peak: float = lerp(1.10, 1.40, intensity)
	var dur: float  = lerp(0.08, 0.20, intensity)
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "scale", Vector2(peak, peak), dur * 0.5)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, dur * 0.5)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)

func _kill_tween() -> void:
	if _anim_tween != null and _anim_tween.is_running():
		_anim_tween.kill()
	scale = Vector2.ONE  # always reset to guarantee a clean starting scale
