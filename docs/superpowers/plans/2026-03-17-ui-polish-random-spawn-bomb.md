# UI Polish, Random Spawn & Bomb Item — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the redundant "SCORE" header label from the TopBar, properly centre end-game overlays, add level-scaled random spawn pools from Lv.3+, and add a bomb item (earned by merging to ≥128, used to shuffle + clear the board with explosion FX).

**Architecture:** All game logic lives in `scripts/Game.gd` and scene data in `scenes/Game.tscn`; level metadata is in `scripts/SaveData.gd`. Each chunk is a self-contained commit. No new files are created — changes are confined to the three existing files.

**Tech Stack:** Godot 4.x · GDScript · `Tween` · `AudioStreamGenerator` · `VBoxContainer`/`HBoxContainer` UI layout

---

## Chunk 1: UI Polish — Remove Title Label + Centre Overlays

### Task 1: Remove the redundant "SCORE" header label from the TopBar

**Files:**
- Modify: `scenes/Game.tscn`

#### Context

`Game.tscn`'s TopBar is an `HBoxContainer` that spans the full top ~12 % of the screen.
The user reports seeing a large, meaningless label in the top-left corner.

The actual scene content (no separate "2048" title node exists — the visible label is `ScoreLabel`):

```
[node name="TopBar" type="HBoxContainer" parent="UI"]
layout_mode = 0
anchor_right = 1.0
anchor_bottom = 0.12

[node name="ScoreBox" type="VBoxContainer" parent="UI/TopBar"]
layout_mode = 2

[node name="ScoreLabel" type="Label" parent="UI/TopBar/ScoreBox"]
layout_mode = 2
text = "SCORE"
horizontal_alignment = 1

[node name="ScoreValue" type="Label" parent="UI/TopBar/ScoreBox"]
layout_mode = 2
text = "0"
horizontal_alignment = 1
```

`ScoreLabel` (text = `"SCORE"`) is the redundant header. The score number (`ScoreValue`) is self-explanatory without it. `ScoreLabel` is not referenced anywhere in `Game.gd`, so it can be safely deleted from the `.tscn` file alone.

- [ ] **Step 1: Delete the `ScoreLabel` node block from `scenes/Game.tscn`**

  Remove this block (including all its properties):

  ```
  [node name="ScoreLabel" type="Label" parent="UI/TopBar/ScoreBox"]
  layout_mode = 2
  text = "SCORE"
  horizontal_alignment = 1
  ```

  Keep `ScoreBox`, `ScoreValue`, and everything else intact.

- [ ] **Step 2: Save `Game.tscn`, then open the scene in Godot and run the game**

  Verify the top-left area shows only the numeric score (e.g. "0") without a "SCORE" header above it.

- [ ] **Step 3: Commit**

```bash
git add scenes/Game.tscn
git commit -m "fix: remove redundant SCORE header label from TopBar"
```

---

### Task 2: Centre the Win overlay

**Files:**
- Modify: `scripts/Game.gd` — function `_show_win()` (lines ~290-335) and `_on_restart_pressed()` (lines ~179-185)

#### Context — current `_show_win()`

```gdscript
func _show_win() -> void:
	merge_audio.stop()
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
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 24)
	$UI.add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)

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

#### Current `_on_restart_pressed()`

```gdscript
func _on_restart_pressed() -> void:
	for node_name in ["GameOverOverlay", "GameOverLabel", "WinOverlay", "WinLabel", "WinButtons"]:
		var node = $UI.get_node_or_null(node_name)
		if node:
			node.queue_free()
	restart()
	_update_display()
```

- [ ] **Step 1: Replace `_show_win()`** with the following:

```gdscript
func _show_win() -> void:
	merge_audio.stop()
	_timer_running = false
	_win_shown = true
	SaveData.submit_record(target_tile, score, elapsed_time)
	SaveData.unlock_next(level_index)

	# Disable bomb button (forward-compatible: BombButton may not exist in Chunk 1)
	var bb := $UI/TopBar.get_node_or_null("BombButton")
	if bb:
		bb.disabled = true

	var overlay := ColorRect.new()
	overlay.name = "WinOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	$UI.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.name = "WinPanel"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 16)
	panel.custom_minimum_size = Vector2(300, 0)
	$UI.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var title_lbl := Label.new()
	title_lbl.text = "🎉 通關！"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_font_size_override("font_size", 28)
	panel.add_child(title_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "分數：%d　時間：%.1f 秒" % [score, elapsed_time]
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_color_override("font_color", Color.WHITE)
	info_lbl.add_theme_font_size_override("font_size", 20)
	panel.add_child(info_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var btn_replay := Button.new()
	btn_replay.text = "再玩一次"
	btn_replay.pressed.connect(_on_win_replay)
	hbox.add_child(btn_replay)

	var btn_next := Button.new()
	btn_next.text = "下一關"
	btn_next.disabled = (level_index >= SaveData.LEVELS.size() - 1)
	btn_next.pressed.connect(_on_win_next)
	hbox.add_child(btn_next)

	var btn_select := Button.new()
	btn_select.text = "返回選關"
	btn_select.pressed.connect(_on_win_select)
	hbox.add_child(btn_select)
```

- [ ] **Step 2: Update `_on_restart_pressed()`** — replace the node-name list to match the new names:

```gdscript
func _on_restart_pressed() -> void:
	for node_name in ["GameOverOverlay", "GameOverPanel", "WinOverlay", "WinPanel"]:
		var node = $UI.get_node_or_null(node_name)
		if node:
			node.queue_free()
	restart()
	_update_display()
```

- [ ] **Step 3: Run the game, complete Lv.1, verify overlay**

  The "🎉 通關！" text, score/time line, and three buttons should all appear visually centred both horizontally and vertically on the screen.

- [ ] **Step 4: Commit**

```bash
git add scripts/Game.gd
git commit -m "fix: centre win overlay using VBoxContainer with PRESET_CENTER"
```

---

### Task 3: Centre the Game-Over overlay

**Files:**
- Modify: `scripts/Game.gd` — function `_show_game_over()` (lines ~349-365)

#### Context — current `_show_game_over()`

```gdscript
func _show_game_over() -> void:
	merge_audio.stop()
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
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 24)
	$UI.add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER)
```

- [ ] **Step 1: Replace `_show_game_over()`** with the following:

```gdscript
func _show_game_over() -> void:
	merge_audio.stop()
	_timer_running = false

	var overlay := ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	$UI.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.name = "GameOverPanel"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 12)
	panel.custom_minimum_size = Vector2(300, 0)
	$UI.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var title_lbl := Label.new()
	title_lbl.text = "遊戲結束！"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_font_size_override("font_size", 28)
	panel.add_child(title_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "最終分數：%d\n按「重新開始」繼續" % score
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_color_override("font_color", Color.WHITE)
	info_lbl.add_theme_font_size_override("font_size", 20)
	panel.add_child(info_lbl)

	# Disable bomb button so the player cannot use it after game-over
	# (bomb_button may not exist yet if Chunk 3 hasn't been implemented;
	#  use get_node_or_null to keep this forward-compatible)
	var bb := $UI/TopBar.get_node_or_null("BombButton")
	if bb:
		bb.disabled = true
```

- [ ] **Step 2: Run the game, trigger a game-over, verify overlay**

  "遊戲結束！" and the score text should appear centred. "重新開始" button (already in BottomBar) still works. Bomb button (if present) should be greyed out.

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "fix: centre game-over overlay using VBoxContainer with PRESET_CENTER"
```

---

## Chunk 2: Level-Scaled Random Spawn Pool

### Task 4: Add spawn pool metadata to SaveData.LEVELS

**Files:**
- Modify: `scripts/SaveData.gd` — `LEVELS` constant (lines 7-13)

#### Context — current `LEVELS`

```gdscript
const LEVELS = [
	{ "target": 128,  "name": "Lv.1 — 128" },
	{ "target": 256,  "name": "Lv.2 — 256" },
	{ "target": 512,  "name": "Lv.3 — 512" },
	{ "target": 1024, "name": "Lv.4 — 1024" },
	{ "target": 2048, "name": "Lv.5 — 2048" },
]
```

- [ ] **Step 1: Replace `LEVELS`** with:

```gdscript
const LEVELS = [
	{
		"target": 128, "name": "Lv.1 — 128",
		"spawn_pool": [2, 4], "spawn_weights": [90, 10],
	},
	{
		"target": 256, "name": "Lv.2 — 256",
		"spawn_pool": [2, 4], "spawn_weights": [90, 10],
	},
	{
		"target": 512, "name": "Lv.3 — 512",
		"spawn_pool": [2, 4, 8, 16], "spawn_weights": [50, 25, 15, 10],
	},
	{
		"target": 1024, "name": "Lv.4 — 1024",
		"spawn_pool": [2, 4, 8, 16, 32], "spawn_weights": [50, 25, 12, 8, 5],
	},
	{
		"target": 2048, "name": "Lv.5 — 2048",
		"spawn_pool": [2, 4, 8, 16, 32, 64], "spawn_weights": [45, 25, 12, 8, 6, 4],
	},
]
```

  Note: each `spawn_weights` array sums to 100, enabling a simple `randi() % 100` pick.

- [ ] **Step 2: Confirm the rest of SaveData.gd compiles**

  In Godot's editor, open `SaveData.gd` and check for any script errors in the Output panel.

- [ ] **Step 3: Commit**

```bash
git add scripts/SaveData.gd
git commit -m "feat: add spawn_pool and spawn_weights metadata to SaveData.LEVELS"
```

---

### Task 5: Rewrite `spawn_tile()` to use weighted pool

**Files:**
- Modify: `scripts/Game.gd` — function `spawn_tile()` (lines ~60-71)

#### Context — current `spawn_tile()`

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

- [ ] **Step 1: Replace `spawn_tile()`** with:

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
	board[cell.x][cell.y] = _pick_spawn_value()
	_last_spawn = cell

func _pick_spawn_value() -> int:
	var level_data: Dictionary = SaveData.LEVELS[level_index]
	var pool: Array    = level_data.get("spawn_pool",    [2, 4])
	var weights: Array = level_data.get("spawn_weights", [90, 10])
	var roll: int = randi() % 100
	var cumulative: int = 0
	for i in pool.size():
		cumulative += weights[i]
		if roll < cumulative:
			return pool[i]
	return pool[-1]  # fallback (should never reach here if weights sum to 100)
```

- [ ] **Step 2: Run the game on Lv.3, 4, 5 and observe spawned tile values**

  After several moves, you should occasionally see tiles with values of 8, 16, 32, or 64 spawning on the appropriate levels.

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: weighted random spawn pool per level from Lv.3 onwards"
```

---

## Chunk 3: Bomb Item

### Task 6: Add BombButton node to Game.tscn

**Files:**
- Modify: `scenes/Game.tscn`

#### Context

Current TopBar section in `Game.tscn`:

```
[node name="TopBar" type="HBoxContainer" parent="UI"]
layout_mode = 0
anchor_right = 1.0
anchor_bottom = 0.12

[node name="ScoreBox" type="VBoxContainer" parent="UI/TopBar"]
layout_mode = 2
...
```

- [ ] **Step 1: Add size_flags to ScoreBox so it expands left**

  In `Game.tscn`, find the `[node name="ScoreBox" ...]` block and add:

```
size_flags_horizontal = 3
```

  (Value `3` = `SIZE_EXPAND_FILL` — pushes `BombButton` to the right.)

- [ ] **Step 2: Append BombButton node** after the ScoreBox block:

```
[node name="BombButton" type="Button" parent="UI/TopBar"]
layout_mode = 2
text = "💣 ×0"
disabled = true
```

- [ ] **Step 3: Append the signal connection** at the end of `Game.tscn` (before the final blank line, alongside existing connections):

```
[connection signal="pressed" from="UI/TopBar/BombButton" to="." method="_on_bomb_pressed"]
```

- [ ] **Step 4: Open scene in Godot, verify TopBar layout**

  Score on the left, 💣 ×0 button (disabled/greyed) on the right.

- [ ] **Step 5: Commit**

```bash
git add scenes/Game.tscn
git commit -m "feat: add BombButton to TopBar in Game.tscn"
```

---

### Task 7: Wire bomb state — declare, award, reset

**Files:**
- Modify: `scripts/Game.gd`

- [ ] **Step 1: Add `@onready` reference and state variable**

  After the existing `@onready` block (around line 11), add:

```gdscript
@onready var bomb_button: Button = $UI/TopBar/BombButton
```

  After the `var _last_spawn` declaration (around line 24), add:

```gdscript
var bomb_count: int = 0
```

- [ ] **Step 2: Add `_update_bomb_ui()` helper** — insert after the `_update_display()` function:

```gdscript
func _update_bomb_ui() -> void:
	bomb_button.text = "💣 ×%d" % bomb_count
	bomb_button.disabled = (bomb_count == 0 or _win_shown or is_game_over())
```

- [ ] **Step 3: Award bombs in `_try_move()`**

  The existing animation loop in `_try_move()` already reads:

```gdscript
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
```

  Replace that block with:

```gdscript
		# --- animations + bomb award ---
		var tone_played  := false
		var bomb_earned  := false
		for row in BOARD_SIZE:
			for col in BOARD_SIZE:
				if board[row][col] > pre_board[row][col] and board[row][col] > 0 \
						and Vector2i(row, col) != _last_spawn:
					tile_nodes[row][col].animate_merge(board[row][col])
					if not tone_played:
						_play_merge_tone(board[row][col])
						tone_played = true
					if not bomb_earned and board[row][col] >= 128:
						bomb_earned = true
		if bomb_earned:
			bomb_count += 2
			_update_bomb_ui()
```

- [ ] **Step 4: Reset `bomb_count` in `restart()`**

  Inside `restart()`, after `_win_shown = false`, add:

```gdscript
	bomb_count = 0
	_update_bomb_ui()
```

- [ ] **Step 5: Run the game, merge to 128+, verify button updates**

  Merging two 64-tiles should immediately change the button to "💣 ×2" and enable it.

- [ ] **Step 6: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: bomb_count state, award 2 bombs on merge >= 128, reset on restart"
```

---

### Task 8: Implement `_use_bomb()` — shuffle + clear

**Files:**
- Modify: `scripts/Game.gd`

- [ ] **Step 1: Add `_on_bomb_pressed()` and `_use_bomb()`** — append after `_update_bomb_ui()`:

```gdscript
func _on_bomb_pressed() -> void:
	_use_bomb()

func _use_bomb() -> void:
	if bomb_count == 0 or _win_shown or is_game_over():
		return
	bomb_count -= 1
	_update_bomb_ui()

	# Collect all non-zero positions and values
	var positions: Array = []
	var values: Array    = []
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			if board[row][col] != 0:
				positions.append(Vector2i(row, col))
				values.append(board[row][col])

	# Randomly redistribute values across same positions
	values.shuffle()
	for i in positions.size():
		board[positions[i].x][positions[i].y] = values[i]

	# Clear the 2 cells that now hold the smallest values
	positions.sort_custom(func(a, b):
		return board[a.x][a.y] < board[b.x][b.y]
	)
	var to_clear: int = min(2, positions.size())
	for i in to_clear:
		board[positions[i].x][positions[i].y] = 0

	# Undo history is invalid after a shuffle
	history.clear()

	_play_bomb_animation()
	_play_bomb_tone()
	_update_display()
```

- [ ] **Step 2: Run the game, earn bombs, press the bomb button**

  Board values should rearrange and two of the smallest tiles should disappear. Undo should become disabled.

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: _use_bomb shuffles board and clears 2 smallest tiles"
```

---

### Task 9: Implement `_play_bomb_animation()`

**Files:**
- Modify: `scripts/Game.gd`

- [ ] **Step 1: Add `_play_bomb_animation()`** — append after `_use_bomb()`:

```gdscript
func _play_bomb_animation() -> void:
	# Scale-pulse the board container
	var board_tween := create_tween()
	board_tween.tween_property(board_container, "scale", Vector2(1.05, 1.05), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	board_tween.tween_property(board_container, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	# Full-screen white flash that fades out
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	flash_tween.tween_callback(flash.queue_free)  # self-cleaning node
```

- [ ] **Step 2: Run the game, use a bomb, verify animation**

  Board should briefly enlarge (~5 %) and a white flash should fade out over ~0.4 s.

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: bomb explosion animation — board pulse + white flash overlay"
```

---

### Task 10: Implement `_play_bomb_tone()`

**Files:**
- Modify: `scripts/Game.gd`

#### Context

The existing `MergeAudio` node (`AudioStreamPlayer`) is already set up in `_ready()` with an `AudioStreamGenerator`. The same node is reused for the bomb sound. A sawtooth wave at 80 Hz produces a low rumble distinctly different from the sine-wave merge tone.

- [ ] **Step 1: Add `_play_bomb_tone()`** — append after `_play_bomb_animation()`:

```gdscript
func _play_bomb_tone() -> void:
	var playback := merge_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var freq   := 80.0
	var dur    := 0.3
	var sr     := float(AUDIO_SAMPLE_RATE)
	var frames := int(sr * dur)
	playback.clear_buffer()
	for i in frames:
		var t     := float(i) / sr
		var amp   := 0.4 * (1.0 - t / dur)          # linear decay envelope
		var phase := fmod(freq * t, 1.0)             # sawtooth phase 0..1
		var s     := (2.0 * phase - 1.0) * amp       # sawtooth -1..1, scaled
		playback.push_frame(Vector2(s, s))
```

  **Expected values for manual verification:**
  - `freq = 80 Hz`, `dur = 0.3 s`, `frames = 6615`
  - At `t = 0`: `amp = 0.4`, `s` oscillates between –0.4 and +0.4
  - At `t = 0.15 s`: `amp = 0.2`
  - At `t = 0.3 s`: `amp ≈ 0` (silent)

- [ ] **Step 2: Run the game, use a bomb, verify audio**

  A short low-pitched rumble (~80 Hz, 0.3 s) should play simultaneously with the visual flash. It should sound clearly different from the higher-pitched merge tones.

- [ ] **Step 3: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: bomb explosion sound — 80 Hz sawtooth rumble via AudioStreamGenerator"
```

---

## Integration Smoke-Test Checklist (manual, run after all chunks)

Run the game and verify:

- [ ] Top-left corner has no large "2048" or redundant title text
- [ ] Win overlay: "🎉 通關！", score, time, and three buttons all appear centred on screen
- [ ] Game-over overlay: "遊戲結束！" and score appear centred; "重新開始" still works
- [ ] Lv.1/2: only 2 or 4 spawn (same as before)
- [ ] Lv.3: occasionally see 8 or 16 tiles appear after moves
- [ ] Lv.4: occasionally see 8, 16, or 32 tiles
- [ ] Lv.5: occasionally see 8, 16, 32, or 64 tiles
- [ ] Merging two 64-tiles → "💣 ×2" button becomes enabled
- [ ] Pressing 💣 while count=0 → does nothing
- [ ] Pressing 💣 while count≥1: count decreases, board shuffles, 2 tiles cleared, pulse+flash play, rumble plays
- [ ] After using bomb: undo is disabled
- [ ] restart() → bomb count resets to 0, button re-disabled
