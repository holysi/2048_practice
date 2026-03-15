# Merge Animation & Procedural Sound Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix win-screen buttons not rendering, add scale-pop animations on tile merge/spawn (intensity proportional to merged value), and add procedural sine-wave audio (pitch proportional to merged value).

**Architecture:** Three independent changes — (1) reorder `add_child` / `set_anchors_preset` calls in `_show_win` and `_show_game_over` so anchor resolution has a valid parent size, (2) add two animation methods to `Tile.gd` driven by `Tween`, (3) synthesise audio samples via `AudioStreamGenerator` in `Game.gd`.

**Tech Stack:** Godot 4.x · GDScript · Tween · AudioStreamGenerator · AudioStreamGeneratorPlayback

---

## Chunk 1: Win Screen Bug Fix

**Files:**
- Modify: `scripts/Game.gd` (`_show_win`, `_show_game_over`)

> Pure reordering fix — no logic changes. Godot 4's `CanvasLayer` requires `add_child()`
> to be called before `set_anchors_preset()` so that the Control knows its parent's viewport
> size when computing its rect. The current code calls both in the wrong order,
> resulting in a 0×0 rect for the overlay and the button container.

---

### Task 1: Replace `_show_win()` with anchor-safe version

- [ ] **Step 1: Open `scripts/Game.gd` and read `_show_win()` (lines 249–297)**

  The current function constructs `overlay`, `label`, and `hbox`, then adds all three to
  `$UI` in a **batch at the end** (lines 295–297). Both `overlay` and `label` call
  `set_anchors_preset()` before they are in the tree, and `hbox` sets `anchor_*` before
  `$UI.add_child(hbox)` is called. This is the bug.

- [ ] **Step 2: Replace lines 255–297 (the node-building block) with the fixed version**

  **Before (verbatim, lines 255–297):**

  ```gdscript
  	var overlay = ColorRect.new()
  	overlay.name = "WinOverlay"
  	overlay.color = Color(0, 0, 0, 0.7)
  	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

  	var label = Label.new()
  	label.name = "WinLabel"
  	label.text = "🎉 通關！\n分數：%d　時間：%.1f 秒" % [score, elapsed_time]
  	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  	label.set_anchors_preset(Control.PRESET_FULL_RECT)
  	label.add_theme_color_override("font_color", Color.WHITE)
  	label.add_theme_font_size_override("font_size", 32)

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
  	# 手動設定 anchor，避免 set_anchors_preset(PRESET_BOTTOM_WIDE) 在入樹前
  	# 計算 offset_top = -size.y 時 size.y=0 導致高度為零的 bug
  	hbox.anchor_left   = 0.0
  	hbox.anchor_right  = 1.0
  	hbox.anchor_top    = 0.78
  	hbox.anchor_bottom = 1.0
  	hbox.add_child(btn_replay)
  	hbox.add_child(btn_next)
  	hbox.add_child(btn_select)

  	$UI.add_child(overlay)
  	$UI.add_child(label)
  	$UI.add_child(hbox)
  ```

  **After (fixed — `add_child` inlined immediately after each node, anchors set after):**

  ```gdscript
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
  ```

---

### Task 2: Replace `_show_game_over()` with anchor-safe version

- [ ] **Step 1: Locate `_show_game_over()` in `scripts/Game.gd` (line 311)**

- [ ] **Step 2: Replace the node-building block (lines 313–328) with the fixed version**

  **Before (verbatim, lines 313–328):**

  ```gdscript
  	var overlay = ColorRect.new()
  	overlay.name = "GameOverOverlay"
  	overlay.color = Color(0, 0, 0, 0.6)
  	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

  	var label = Label.new()
  	label.name = "GameOverLabel"
  	label.text = "遊戲結束！\n最終分數：" + str(score) + "\n按「重新開始」繼續"
  	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  	label.set_anchors_preset(Control.PRESET_FULL_RECT)
  	label.add_theme_color_override("font_color", Color.WHITE)
  	label.add_theme_font_size_override("font_size", 36)

  	$UI.add_child(overlay)
  	$UI.add_child(label)
  ```

  **After (fixed):**

  ```gdscript
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
  ```

- [ ] **Step 3: Commit both functions together**

  ```bash
  git add scripts/Game.gd
  git commit -m "fix: add_child before set_anchors_preset in _show_win and _show_game_over"
  ```

---

### Task 3: Manual verification of win screen

- [ ] **Step 1: Open the project in Godot 4 editor and run (F5)**

- [ ] **Step 2: Play Lv.1 (target: 128) and merge tiles until 128 appears**

  Expected:
  - Semi-transparent dark overlay fills the **entire** screen
  - "🎉 通關！" label with score and time is visible and centred
  - Three buttons ("再玩一次" / "下一關" / "返回選關") appear at the bottom ~22% of the screen
  - No errors in the Godot Output panel

- [ ] **Step 3: Verify each button works**

  - "再玩一次" → Game scene reloads, board resets, timer starts from 0
  - "下一關" → Game reloads with Lv.2 (target = 256)
  - "返回選關" → LevelSelect scene loads, Lv.2 is now unlocked

- [ ] **Step 4: Trigger game-over (fill board with no valid moves)**

  Expected:
  - Semi-transparent overlay fills the entire screen
  - "遊戲結束！" label with final score is visible and centred
  - No script errors in Output panel
  - Existing "重新開始" bottom-bar button is still reachable and resets the board

---

## Chunk 2: Tile Animations

**Files:**
- Modify: `scripts/Tile.gd` (add animation methods)
- Modify: `scripts/Game.gd` (spawn tracking + animation triggers)

---

### Task 4: Add animation methods to Tile.gd

- [ ] **Step 1: Append the following block to the end of `scripts/Tile.gd`**

  ```gdscript
  var _anim_tween: Tween = null

  func animate_spawn() -> void:
  	_kill_tween()
  	scale = Vector2.ZERO
  	_anim_tween = create_tween()
  	_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.12)\
  		.set_ease(Tween.EASE_OUT)\
  		.set_trans(Tween.TRANS_BACK)

  func animate_merge(value: int) -> void:
  	_kill_tween()
  	var t: float = log(float(value)) / log(2048.0)
  	var peak: float = lerp(1.10, 1.40, t)
  	var dur: float  = lerp(0.08, 0.20, t)
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
  	scale = Vector2.ONE
  ```

  > `log(float(value)) / log(2048.0)` maps value=2 → ~0.09, value=2048 → 1.0.
  > `_kill_tween()` ensures no two tweens fight over `scale` simultaneously.
  > `TRANS_BACK` on spawn produces a springy overshoot that reads as a pop.

- [ ] **Step 2: Commit**

  ```bash
  git add scripts/Tile.gd
  git commit -m "feat: add animate_spawn and animate_merge to Tile.gd"
  ```

---

### Task 5: Track spawn position and trigger animations from Game.gd

- [ ] **Step 1: Add `_last_spawn` variable to `scripts/Game.gd`**

  After `var _win_shown: bool = false`, add:

  ```gdscript
  var _last_spawn: Vector2i = Vector2i(-1, -1)
  ```

- [ ] **Step 2: Rewrite `spawn_tile()` to record `_last_spawn`**

  **Before (verbatim):**
  ```gdscript
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
  ```

  **After (tracks _last_spawn; return type unchanged — still `void`):**
  ```gdscript
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
  ```

  > `_last_spawn` is reset to `(-1,-1)` at the start of every call so stale values never
  > leak when the board is full and no tile is placed.

- [ ] **Step 3: Rewrite `_try_move()` to snapshot the board and trigger animations**

  **Before (verbatim):**
  ```gdscript
  func _try_move(direction: String) -> void:
  	if _win_shown:
  		return
  	if move(direction):
  		_update_display()
  		if _check_win():
  			_show_win()
  		elif is_game_over():
  			_show_game_over()
  ```

  **After:**
  ```gdscript
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
  				if board[row][col] > pre_board[row][col] and board[row][col] > 0:
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
  ```

  > `tone_played` ensures only one tone plays per move — the first merge found in
  > row-major order (top-left → bottom-right). No stacking.
  > `_play_merge_tone` is added in Chunk 3; the call here will produce a "not found"
  > parse error until Task 8 is done. Implement Task 8 before running the game.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/Game.gd
  git commit -m "feat: track spawn cell and trigger merge/spawn animations in _try_move"
  ```

---

### Task 6: Manual verification of animations

- [ ] **Step 1: Run the game in Godot 4 (F5) — skip if Chunk 3 is not yet done**

  > `_play_merge_tone` must exist before the game can run. Either add a stub
  > `func _play_merge_tone(_v: int) -> void: pass` temporarily, or complete Chunk 3 first.

- [ ] **Step 2: Merge two "2" tiles → expect a subtle pop (~1.10× scale) on the resulting "4"**

- [ ] **Step 3: Merge two high-value tiles (e.g., 256+256) → expect a more dramatic pop (~1.25× scale)**

- [ ] **Step 4: Verify new tiles appear with a spring-bounce from scale 0**

- [ ] **Step 5: Make four rapid moves in quick succession → confirm no scale artefacts**

  Expected: each merge/spawn completes its animation cleanly; no tile permanently oversized.

---

## Chunk 3: Procedural Audio

**Files:**
- Modify: `scenes/Game.tscn` (add `AudioStreamPlayer` node)
- Modify: `scripts/Game.gd` (audio setup in `_ready()`, add `_play_merge_tone()`)

---

### Task 7: Add MergeAudio node to Game.tscn

- [ ] **Step 1: Open `scenes/Game.tscn` in a text editor**

  Locate the `[node name="TileContainer" …]` block (line 82) and the
  `[node name="UI" …]` block (line 84). Insert the new node between them.

- [ ] **Step 2: Insert the following node declaration between `TileContainer` and `UI`**

  **Before (lines 82–84, verbatim):**
  ```
  [node name="TileContainer" type="Node2D" parent="."]

  [node name="UI" type="CanvasLayer" parent="."]
  ```

  **After:**
  ```
  [node name="TileContainer" type="Node2D" parent="."]

  [node name="MergeAudio" type="AudioStreamPlayer" parent="."]

  [node name="UI" type="CanvasLayer" parent="."]
  ```

- [ ] **Step 3: Open Godot editor, verify scene tree shows `MergeAudio` as a child of `Game`**

  No errors in the Output panel when opening the scene.

- [ ] **Step 4: Commit**

  ```bash
  git add scenes/Game.tscn
  git commit -m "feat: add MergeAudio AudioStreamPlayer node to Game.tscn"
  ```

---

### Task 8: Wire audio in Game.gd — setup and tone synthesis

- [ ] **Step 1: Add `@onready` reference for `MergeAudio` in `scripts/Game.gd`**

  After the last `@onready` line (`board_container`), add:

  ```gdscript
  @onready var merge_audio: AudioStreamPlayer = $MergeAudio
  ```

- [ ] **Step 2: Add audio setup at the end of `_ready()`, after `_update_display()`**

  The current `_ready()` ends with:
  ```gdscript
  	await get_tree().process_frame
  	_update_display()
  ```

  Append after `_update_display()`:
  ```gdscript
  	# --- audio setup ---
  	var gen := AudioStreamGenerator.new()
  	gen.mix_rate = 22050.0
  	gen.buffer_length = 0.1
  	merge_audio.stream = gen
  	merge_audio.play()
  ```

  > `merge_audio.play()` must be called so `get_stream_playback()` returns a non-null
  > `AudioStreamGeneratorPlayback`. The player runs silently until we push samples.

- [ ] **Step 3: Add `_play_merge_tone(value: int)` at the end of `scripts/Game.gd`**

  ```gdscript
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
  ```

  > Frequency mapping: `330 * 4^(log(value)/log(2048))` → 330 Hz at value=2, 1320 Hz at value=2048 (two octaves).
  > `playback.clear_buffer()` discards leftover samples from previous tone → clean restart, no overlap.
  > `amp` fades linearly to zero over `dur` seconds to prevent a click at the end.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/Game.gd
  git commit -m "feat: add procedural sine-wave merge tone via AudioStreamGenerator"
  ```

---

### Task 9: Manual verification of audio

- [ ] **Step 1: Run the game (F5) with system audio output enabled**

- [ ] **Step 2: Merge two "2" tiles (result = 4) → hear a short, low-pitched beep (~424 Hz)**

  > Frequency: `330 * 4^(log(4)/log(2048))` = `330 * 4^(2/11)` ≈ 424 Hz

- [ ] **Step 3: Merge two "256" tiles (result = 512) → hear a noticeably higher beep (~1025 Hz)**

  > Frequency: `330 * 4^(9/11)` ≈ 1025 Hz

- [ ] **Step 4: Merge two "1024" tiles (result = 2048) → hear the highest beep (~1320 Hz)**

  > Frequency: `330 * 4^(11/11)` = `330 * 4` = 1320 Hz

- [ ] **Step 5: Make four rapid successive merges → confirm no crash or distortion**

- [ ] **Step 6: Let game reach win screen → confirm no looping tone after win**

---

### Task 10: Full integration smoke test

- [ ] **Step 1: Delete save data for a clean run**

  Path on Windows:
  `C:\Users\<username>\AppData\Roaming\Godot\app_userdata\2048\save.json`

- [ ] **Step 2: Launch game → LevelSelect appears with only Lv.1 unlocked**

- [ ] **Step 3: Start Lv.1, play until 128 tile appears**

  Expected: merge pop animation visible on each merge; tone audible on each merge;
  win overlay + text + three buttons appear correctly.

- [ ] **Step 4: Click "再玩一次" → game reloads same level, timer resets, animations and audio still work**

- [ ] **Step 5: Win Lv.1 again → click "下一關" → Lv.2 (target 256) loads**

- [ ] **Step 6: In Lv.2, trigger game-over → overlay and text appear, no crash**

- [ ] **Step 7: Click "重新開始" → board resets, timer resets, animations and audio work normally**
