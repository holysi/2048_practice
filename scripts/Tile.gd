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
