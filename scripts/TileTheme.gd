# scripts/TileTheme.gd
class_name TileTheme
extends Resource

@export var tile_colors: Dictionary = {
	2:    Color("#f9e4b7"),
	4:    Color("#f4c87a"),
	8:    Color("#f4a23a"),
	16:   Color("#f07f3a"),
	32:   Color("#e05a3a"),
	64:   Color("#d03a2a"),
	128:  Color("#f9d84a"),
	256:  Color("#f9c43a"),
	512:  Color("#e8a020"),
	1024: Color("#8bc34a"),
	2048: Color("#4caf50"),
}

@export var text_color_dark: Color = Color("#776e65")
@export var text_color_light: Color = Color("#ffffff")
@export var tile_corner_radius: float = 12.0
@export var background_color: Color = Color("#faf0e6")
@export var board_color: Color = Color("#bbada0")
@export var empty_cell_color: Color = Color("#cdc1b4")
@export var font: Font  # 選填；若未指定，使用 Godot 預設主題字型

func get_tile_color(value: int) -> Color:
	if tile_colors.has(value):
		return tile_colors[value]
	return Color("#3d3a32")  # 超過 2048 的磁磚用深色

func get_text_color(value: int) -> Color:
	return text_color_dark if value <= 4 else text_color_light
