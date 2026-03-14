# scripts/Game.gd
extends Node2D

@export var tile_theme: TileTheme
@export var tile_scene: PackedScene

@onready var tile_container: Node2D = $TileContainer
@onready var score_value: Label = $UI/TopBar/ScoreBox/ScoreValue
@onready var undo_button: Button = $UI/BottomBar/UndoButton
@onready var board_container: AspectRatioContainer = $BoardContainer

var tile_nodes: Array = []  # 2D Array，對應 board 位置

const BOARD_SIZE = 4
const MAX_HISTORY = 3

var board: Array = []
var score: int = 0
var history: Array = []  # 每筆: {"board": Array, "score": int}

func _ready() -> void:
	_init_board()
	_create_tile_nodes()
	spawn_tile()
	spawn_tile()
	# 等待一個 frame 讓 layout 完成，確保 board_container.size 已計算
	await get_tree().process_frame
	_update_display()

func _init_board() -> void:
	board = []
	for i in BOARD_SIZE:
		var row: Array = []
		for j in BOARD_SIZE:
			row.append(0)
		board.append(row)

func spawn_tile() -> void:
	var empty_cells: Array = []
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			if board[row][col] == 0:
				empty_cells.append(Vector2i(row, col))
	if empty_cells.is_empty():
		return
	var cell = empty_cells[randi() % empty_cells.size()]
	board[cell.x][cell.y] = 4 if randf() < 0.1 else 2

# 將一列向左合併，回傳 [新列, 本次得分]
func _merge_row_left(row: Array) -> Array:
	var tiles = row.filter(func(v): return v != 0)
	var merged: Array = []
	var gained: int = 0
	var i = 0
	while i < tiles.size():
		if i + 1 < tiles.size() and tiles[i] == tiles[i + 1]:
			merged.append(tiles[i] * 2)
			gained += tiles[i] * 2
			i += 2
		else:
			merged.append(tiles[i])
			i += 1
	while merged.size() < BOARD_SIZE:
		merged.append(0)
	return [merged, gained]

# 回傳 true 表示棋盤有改變
func move(direction: String) -> bool:
	var new_board = _copy_board(board)
	var gained = 0

	match direction:
		"left":
			for row in BOARD_SIZE:
				var res = _merge_row_left(new_board[row])
				new_board[row] = res[0]
				gained += res[1]
		"right":
			for row in BOARD_SIZE:
				var reversed = new_board[row].duplicate()
				reversed.reverse()
				var res = _merge_row_left(reversed)
				res[0].reverse()
				new_board[row] = res[0]
				gained += res[1]
		"up":
			for col in BOARD_SIZE:
				var column = []
				for row in BOARD_SIZE:
					column.append(new_board[row][col])
				var res = _merge_row_left(column)
				for row in BOARD_SIZE:
					new_board[row][col] = res[0][row]
				gained += res[1]
		"down":
			for col in BOARD_SIZE:
				var column = []
				for row in BOARD_SIZE:
					column.append(new_board[row][col])
				column.reverse()
				var res = _merge_row_left(column)
				res[0].reverse()
				for row in BOARD_SIZE:
					new_board[row][col] = res[0][row]
				gained += res[1]

	if new_board == board:
		return false  # 沒有移動發生

	# 儲存至歷史
	if history.size() >= MAX_HISTORY:
		history.pop_front()
	history.append({"board": _copy_board(board), "score": score})

	board = new_board
	score += gained
	spawn_tile()
	return true

func _copy_board(src: Array) -> Array:
	var copy = []
	for row in src:
		copy.append(row.duplicate())
	return copy

func _create_tile_nodes() -> void:
	tile_nodes = []
	for row in BOARD_SIZE:
		var row_nodes: Array = []
		for col in BOARD_SIZE:
			var tile: Tile = tile_scene.instantiate()
			tile_container.add_child(tile)
			tile.setup(tile_theme)
			row_nodes.append(tile)
		tile_nodes.append(row_nodes)

func _update_display() -> void:
	var cell_size: Vector2 = board_container.size / BOARD_SIZE
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var tile: Tile = tile_nodes[row][col]
			tile.value = board[row][col]
			tile.size = cell_size
			tile.position = board_container.position + Vector2(col * cell_size.x, row * cell_size.y)
	score_value.text = str(score)
	undo_button.disabled = history.is_empty()

func _on_undo_pressed() -> void:
	if undo():
		_update_display()

func _on_restart_pressed() -> void:
	# 清除 game over 覆蓋層（如果存在）
	var overlay = $UI.get_node_or_null("GameOverOverlay")
	var label = $UI.get_node_or_null("GameOverLabel")
	if overlay:
		overlay.queue_free()
	if label:
		label.queue_free()
	restart()
	_update_display()

func undo() -> bool:
	if history.is_empty():
		return false
	var last = history.pop_back()
	board = last["board"]
	score = last["score"]
	return true

func restart() -> void:
	history.clear()
	score = 0
	_init_board()
	spawn_tile()
	spawn_tile()

func is_game_over() -> bool:
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			if board[row][col] == 0:
				return false
			if col + 1 < BOARD_SIZE and board[row][col] == board[row][col + 1]:
				return false
			if row + 1 < BOARD_SIZE and board[row][col] == board[row + 1][col]:
				return false
	return true
