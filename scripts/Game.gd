# scripts/Game.gd
extends Node2D

const BOARD_SIZE = 4
const MAX_HISTORY = 3

var board: Array = []
var score: int = 0
var history: Array = []  # 每筆: {"board": Array, "score": int}

func _ready() -> void:
	_init_board()
	spawn_tile()
	spawn_tile()

func _init_board() -> void:
	board = []
	for i in BOARD_SIZE:
		board.append([0, 0, 0, 0])

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
