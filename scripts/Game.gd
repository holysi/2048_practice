# scripts/Game.gd
extends Node2D

@export var tile_theme: TileTheme
@export var tile_scene: PackedScene

@onready var tile_container: Node2D = $TileContainer
@onready var score_value: Label = $UI/TopBar/ScoreBox/ScoreValue
@onready var undo_button: Button = $UI/BottomBar/UndoButton
@onready var board_container: AspectRatioContainer = $BoardContainer
@onready var merge_audio: AudioStreamPlayer = $MergeAudio

var tile_nodes: Array = []  # 2D Array，對應 board 位置

const BOARD_SIZE = 4
const MAX_HISTORY = 3

var target_tile: int = 2048
var level_index: int = 4
var elapsed_time: float = 0.0
var _timer_running: bool = false
var _win_shown: bool = false
var _last_spawn: Vector2i = Vector2i(-1, -1)

var board: Array = []
var score: int = 0
var history: Array = []  # 每筆: {"board": Array, "score": int}

func _ready() -> void:
	level_index = clamp(SaveData.current_level_index, 0, SaveData.LEVELS.size() - 1)
	target_tile = SaveData.LEVELS[level_index]["target"]
	_timer_running = true
	_init_board()
	_create_tile_nodes()
	spawn_tile()
	spawn_tile()
	# 等待一個 frame 讓 layout 完成，確保 board_container.size 已計算
	await get_tree().process_frame
	_update_display()
	# --- audio setup ---
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	merge_audio.stream = gen
	merge_audio.play()

func _process(delta: float) -> void:
	if _timer_running:
		elapsed_time += delta

func _init_board() -> void:
	board = []
	for i in BOARD_SIZE:
		var row: Array = []
		for j in BOARD_SIZE:
			row.append(0)
		board.append(row)

func spawn_tile() -> void:
	_last_spawn = Vector2i(-1, -1)
	var empty_cells: Array = []
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			if board[row][col] == 0:
				empty_cells.append(Vector2i(row, col))
	if empty_cells.is_empty():
		return
	var cell: Vector2i = empty_cells[randi() % empty_cells.size()]
	board[cell.x][cell.y] = 4 if randf() < 0.1 else 2
	_last_spawn = cell

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
	var board_rect: Rect2 = board_container.get_global_rect()
	var cell_size: Vector2 = board_rect.size / BOARD_SIZE
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var tile: Tile = tile_nodes[row][col]
			tile.value = board[row][col]
			tile.size = cell_size
			tile.position = board_rect.position + Vector2(col * cell_size.x, row * cell_size.y)
	score_value.text = str(score)
	undo_button.disabled = history.is_empty()

func _on_undo_pressed() -> void:
	if _win_shown:
		return
	if undo():
		_update_display()

func _on_restart_pressed() -> void:
	for node_name in ["GameOverOverlay", "GameOverLabel", "WinOverlay", "WinLabel", "WinButtons"]:
		var node = $UI.get_node_or_null(node_name)
		if node:
			node.queue_free()
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
	elapsed_time = 0.0
	_timer_running = true
	_win_shown = false
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

var _touch_start: Vector2 = Vector2.ZERO
const SWIPE_THRESHOLD = 50.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var direction = ""
		match event.keycode:
			KEY_UP, KEY_W:    direction = "up"
			KEY_DOWN, KEY_S:  direction = "down"
			KEY_LEFT, KEY_A:  direction = "left"
			KEY_RIGHT, KEY_D: direction = "right"
		if direction != "":
			_try_move(direction)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			var delta = event.position - _touch_start
			if delta.length() >= SWIPE_THRESHOLD:
				var direction = ""
				if abs(delta.x) > abs(delta.y):
					direction = "right" if delta.x > 0 else "left"
				else:
					direction = "down" if delta.y > 0 else "up"
				_try_move(direction)

func _try_move(direction: String) -> void:
	if _win_shown:
		return
	var pre_board: Array = _copy_board(board)
	if move(direction):
		_update_display()
		# --- animations ---
		var tone_played := false
		for row in BOARD_SIZE:
			for col in BOARD_SIZE:
				if board[row][col] > pre_board[row][col] and board[row][col] > 0 \
						and Vector2i(row, col) != _last_spawn:
					tile_nodes[row][col].animate_merge(board[row][col])
					if not tone_played:
						_play_merge_tone(board[row][col])
						tone_played = true
		if _last_spawn != Vector2i(-1, -1):
			tile_nodes[_last_spawn.x][_last_spawn.y].animate_spawn()
		# --- win / game-over (unchanged) ---
		if _check_win():
			_show_win()
		elif is_game_over():
			_show_game_over()

func _play_merge_tone(value: int) -> void:
	var playback := merge_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var freq    := 330.0 * pow(4.0, log(float(value)) / log(2048.0))
	var dur     := 0.06
	var sr      := 22050.0
	var frames  := int(sr * dur)
	playback.clear_buffer()
	for i in frames:
		var t   := float(i) / sr
		var amp := 0.5 * (1.0 - t / dur)
		var s   := sin(TAU * freq * t) * amp
		playback.push_frame(Vector2(s, s))

func _check_win() -> bool:
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			if board[row][col] >= target_tile:
				return true
	return false

func _show_win() -> void:
	_timer_running = false
	_win_shown = true
	SaveData.submit_record(target_tile, score, elapsed_time)
	SaveData.unlock_next(level_index)

	var overlay = ColorRect.new()
	overlay.name = "WinOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	$UI.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label = Label.new()
	label.name = "WinLabel"
	label.text = "🎉 通關！\n分數：%d　時間：%.1f 秒" % [score, elapsed_time]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 32)
	$UI.add_child(label)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	var btn_replay = Button.new()
	btn_replay.text = "再玩一次"
	btn_replay.pressed.connect(_on_win_replay)

	var btn_next = Button.new()
	btn_next.text = "下一關"
	btn_next.disabled = (level_index >= SaveData.LEVELS.size() - 1)
	btn_next.pressed.connect(_on_win_next)

	var btn_select = Button.new()
	btn_select.text = "返回選關"
	btn_select.pressed.connect(_on_win_select)

	var hbox = HBoxContainer.new()
	hbox.name = "WinButtons"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_replay)
	hbox.add_child(btn_next)
	hbox.add_child(btn_select)
	$UI.add_child(hbox)
	hbox.anchor_left   = 0.0
	hbox.anchor_right  = 1.0
	hbox.anchor_top    = 0.78
	hbox.anchor_bottom = 1.0

func _on_win_replay() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_win_next() -> void:
	if level_index >= SaveData.LEVELS.size() - 1:
		return
	SaveData.current_level_index = level_index + 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_win_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _show_game_over() -> void:
	_timer_running = false
	var overlay = ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	$UI.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var label = Label.new()
	label.name = "GameOverLabel"
	label.text = "遊戲結束！\n最終分數：" + str(score) + "\n按「重新開始」繼續"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 36)
	$UI.add_child(label)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
