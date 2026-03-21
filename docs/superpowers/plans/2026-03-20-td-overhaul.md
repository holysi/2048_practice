# TD Overhaul Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the Tower Defense panel with a 64×64 grid, corner-only tower slots, lives=0 game-over state (enemies pause, bombs still usable), starting gold=100, and symmetric 50/50 panel layout.

**Architecture:** Changes flow outward from GameManager (shared state) → Game.gd (2048 side syncs bomb_count) → HybridGame.tscn (layout) → TowerDefense.gd (grid, slots, game-over) → WaveManager.gd (pause support). Each task is independently committable.

**Tech Stack:** Godot 4.x, GDScript. No external test framework — verification is "open scene, run, observe Output panel for errors, check visually."

---

## Chunk 1: Foundation — GameManager, Game.gd sync, panel layout

---

### Task 1: GameManager — STARTING_GOLD, bomb_count forward, reset fix

**Files:**
- Modify: `scripts/GameManager.gd`

**What:** Add `STARTING_GOLD = 100`, set initial gold to 100, add `_bomb_count`/`bomb_count` forward property so TowerDefense can read bomb count without importing Game.gd, fix `reset()` to use the constant and reset bomb_count.

- [ ] **Step 1: Open `scripts/GameManager.gd` and apply all changes at once**

Replace the entire file with:

```gdscript
# scripts/GameManager.gd
extends Node

signal gold_changed(new_total: int)
signal bomb_aoe_requested(world_position: Vector2)

const GOLD_PER_MILESTONE: int = 20
const SCORE_MILESTONE: int = 200
const STARTING_GOLD: int = 100

var gold: int = STARTING_GOLD
var _last_milestone_score: int = 0

var _bomb_count: int = 0          # backing variable — synced from Game.gd
var bomb_count: int:
	get: return _bomb_count
	set(v): _bomb_count = v

## Called by Game.gd after every successful move.
func report_score(new_score: int) -> void:
	var milestones_passed := (new_score - _last_milestone_score) / SCORE_MILESTONE
	if milestones_passed > 0:
		gold += milestones_passed * GOLD_PER_MILESTONE
		_last_milestone_score += milestones_passed * SCORE_MILESTONE
		gold_changed.emit(gold)

## Called by TowerDefense.gd to purchase towers.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## Called when enemies are killed or other gold rewards are granted.
func earn_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

## Called by HybridGame.gd when bomb AOE is triggered on the TD area.
func request_bomb_aoe(world_pos: Vector2) -> void:
	bomb_aoe_requested.emit(world_pos)

## Called on TD restart — restores starting gold and clears milestone counter.
func reset() -> void:
	gold = STARTING_GOLD
	_last_milestone_score = 0
	_bomb_count = 0
	gold_changed.emit(gold)
```

- [ ] **Step 2: Open Godot, run the project (F5), confirm no script errors in Output**

Expected: no parse errors. Gold display in TD top bar should show 100 at startup.
(TowerDefense connects to `GameManager.gold_changed` in its `_ready()` and updates `gold_label` — the label updates because `gold` is initialised to `STARTING_GOLD = 100`. If it shows 0, check that `GameManager.gd` is still registered as an Autoload.)

- [ ] **Step 3: Commit**

```bash
git add scripts/GameManager.gd
git commit -m "feat: GameManager STARTING_GOLD=100, bomb_count forwarding, reset fix"
```

---

### Task 2: Game.gd — sync bomb_count to GameManager

**Files:**
- Modify: `scripts/Game.gd` (lines 187–199, 297, 364–365, 406, 504)

**What:** Sync `bomb_count` → `GameManager.bomb_count` at two callsites: `_update_bomb_ui()` (called after every mutation via lines 198, 298, 365, 406, 504) and `_use_bomb()` directly (belt-and-suspenders, matching spec). This ensures TowerDefense always reads the correct value from GameManager.

- [ ] **Step 1: Find `_update_bomb_ui()` in `scripts/Game.gd`**

Current (around line 187):
```gdscript
func _update_bomb_ui() -> void:
	bomb_button.text = "💣 ×%d" % bomb_count
	bomb_button.disabled = (bomb_count == 0 or _win_shown or is_game_over())
```

- [ ] **Step 2: Add the sync line to `_update_bomb_ui`**

Replace with:
```gdscript
func _update_bomb_ui() -> void:
	bomb_button.text = "💣 ×%d" % bomb_count
	bomb_button.disabled = (bomb_count == 0 or _win_shown or is_game_over())
	GameManager.bomb_count = bomb_count   # keep TowerDefense informed
```

- [ ] **Step 3: Find `_use_bomb()` in `scripts/Game.gd`**

Current (around line 194):
```gdscript
func _use_bomb() -> void:
	if bomb_count == 0 or _win_shown:
		return
	bomb_count -= 1
	_update_bomb_ui()
```

The sync fires through `_update_bomb_ui()` here too, but add an explicit sync after decrement for clarity and safety:
```gdscript
func _use_bomb() -> void:
	if bomb_count == 0 or _win_shown:
		return
	bomb_count -= 1
	GameManager.bomb_count = bomb_count   # explicit sync before AOE
	_update_bomb_ui()
```

- [ ] **Step 4: Run the project (F5), confirm no errors**

Expected: Output panel clean. Bomb button still works in 2048.

- [ ] **Step 5: Commit**

```bash
git add scripts/Game.gd
git commit -m "feat: sync bomb_count to GameManager from _update_bomb_ui and _use_bomb"
```

---

### Task 3: HybridGame.tscn — 50/50 panel split

**Files:**
- Modify: `scenes/HybridGame.tscn`

**What:** Change LeftPanel's `anchor_right` from `0.45` to `0.5`, and RightPanel's `anchor_left` from `0.45` to `0.5`. Both panels become equal width.

- [ ] **Step 1: Open `scenes/HybridGame.tscn` in a text editor**

Find the `[node name="LeftPanel"` block:
```
[node name="LeftPanel" type="Control" parent="."]
layout_mode = 1
anchor_right = 0.45
anchor_bottom = 1.0
```

Change `anchor_right = 0.45` → `anchor_right = 0.5`

- [ ] **Step 2: Find the `[node name="RightPanel"` block**

```
[node name="RightPanel" type="Control" parent="."]
layout_mode = 1
anchor_left = 0.45
anchor_right = 1.0
anchor_bottom = 1.0
```

Change `anchor_left = 0.45` → `anchor_left = 0.5`

- [ ] **Step 3: Run the project (F5), confirm layout**

Expected: 2048 and TD panels are visually equal-width side by side. No errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/HybridGame.tscn
git commit -m "feat: 50/50 panel split in HybridGame.tscn"
```

---

## Chunk 2: TD Core Overhaul — Grid, WaveManager pause, game-over, corner slots, bottom bar

---

### Task 4: TowerDefense.gd — 64×64 grid with uniform cell_size and grid_offset

**Files:**
- Modify: `scripts/TowerDefense.gd`

**What:** Replace `GRID_COLS=10, GRID_ROWS=14` with `GRID_COLS=64, GRID_ROWS=64`. Replace the non-uniform `size / Vector2(GRID_COLS, GRID_ROWS)` cell size with a uniform scalar `cell_size: float` computed via `_compute_cell_size()`. Add `grid_offset: Vector2` so the grid starts below the top bar and is horizontally centered. Rewrite `cell_to_world`, `world_to_cell`, `_is_cell_on_path` to use the new vars. Update `_build_world_waypoints` to apply `grid_offset`.

The top bar and bottom bar each take `UI_BAR_H = 32` pixels. The grid occupies the remaining height, centered horizontally.

- [ ] **Step 1: Replace constants and add new vars at top of TowerDefense.gd**

Find:
```gdscript
const GRID_COLS: int = 10
const GRID_ROWS: int = 14
const MAX_LIVES: int = 20
```

Replace with:
```gdscript
const GRID_COLS: int = 64
const GRID_ROWS: int = 64
const MAX_LIVES: int = 20
const UI_BAR_H: int = 32   # height of top and bottom info bars (px)
```

Then find the `var _selected_tower_type` block and add two new vars:
```gdscript
var cell_size: float = 1.0    # computed in _ready after layout
var grid_offset: Vector2 = Vector2.ZERO   # offset from TowerDefense origin to grid top-left
```

- [ ] **Step 2: Add `_compute_cell_size()` method and update `_ready` call order**

The spec's formula centers the grid by aspect ratio alone. This plan intentionally departs from that: it reserves `UI_BAR_H` pixels at the top (so the grid does not draw under the info bar). `grid_offset.y = UI_BAR_H` pins the grid below the top bar. This is a deliberate improvement over the spec formula.

Add the new method (insert before `_build_world_waypoints`):
```gdscript
func _compute_cell_size() -> void:
	var available_w: float = size.x
	var available_h: float = size.y - 2.0 * UI_BAR_H
	cell_size = min(available_w / GRID_COLS, available_h / GRID_ROWS)
	var grid_w: float = cell_size * GRID_COLS
	var grid_h: float = cell_size * GRID_ROWS
	# grid_offset.y = UI_BAR_H: grid starts below top bar
	# grid_offset.x: center horizontally if grid is narrower than panel
	grid_offset = Vector2((size.x - grid_w) / 2.0, float(UI_BAR_H))
```

The full corrected call order in `_ready` (after `await get_tree().process_frame`) must be:
```gdscript
await get_tree().process_frame
if not is_instance_valid(self):
	return
_compute_cell_size()        # 1. must run first — cell_size/grid_offset used by everything below
_build_world_waypoints()    # 2. uses cell_size + grid_offset
_init_grid()                # 3. calls _is_cell_on_path → uses cell_size + grid_offset
_draw_path()
_setup_wave_manager()
```

Verify that `_ready` already calls these in this order; if `_init_grid()` appears before `_build_world_waypoints()` in the original, swap them too.

- [ ] **Step 3: Rewrite `_build_world_waypoints`**

Find:
```gdscript
func _build_world_waypoints() -> void:
	_world_waypoints.clear()
	for npt in WAYPOINTS_NORMALIZED:
		_world_waypoints.append(npt * size)
```

Replace with:
```gdscript
func _build_world_waypoints() -> void:
	_world_waypoints.clear()
	var grid_size := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
	for npt in WAYPOINTS_NORMALIZED:
		_world_waypoints.append(grid_offset + npt * grid_size)
```

- [ ] **Step 4: Rewrite `cell_to_world` and `world_to_cell`**

Find:
```gdscript
func cell_to_world(cell: Vector2i) -> Vector2:
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	return Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	return Vector2i(int(world_pos.x / cell_size.x), int(world_pos.y / cell_size.y))
```

Replace with:
```gdscript
func cell_to_world(cell: Vector2i) -> Vector2:
	return grid_offset + Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - grid_offset
	return Vector2i(int(local.x / cell_size), int(local.y / cell_size))
```

- [ ] **Step 5: Rewrite `_is_cell_on_path`**

Find:
```gdscript
func _is_cell_on_path(row: int, col: int) -> bool:
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	var cell_center := Vector2(col + 0.5, row + 0.5) * cell_size
	for i in range(_world_waypoints.size() - 1):
		var a: Vector2 = _world_waypoints[i]
		var b: Vector2 = _world_waypoints[i + 1]
		if _dist_point_to_segment(cell_center, a, b) < cell_size.x * 0.6:
			return true
	return false
```

Replace with:
```gdscript
func _is_cell_on_path(row: int, col: int) -> bool:
	var cell_center := grid_offset + Vector2(col + 0.5, row + 0.5) * cell_size
	for i in range(_world_waypoints.size() - 1):
		var a: Vector2 = _world_waypoints[i]
		var b: Vector2 = _world_waypoints[i + 1]
		if _dist_point_to_segment(cell_center, a, b) < cell_size * 0.6:
			return true
	return false
```

- [ ] **Step 6: Run the project (F5), confirm no parse errors and TD grid renders**

Expected: TD panel shows a tiny 64×64 grid. The path is a thin brown serpentine. No errors in Output. The grid respects the top/bottom bars.

- [ ] **Step 7: Commit**

```bash
git add scripts/TowerDefense.gd
git commit -m "feat: TD grid 64x64, uniform cell_size + grid_offset with UI_BAR_H"
```

---

### Task 5: WaveManager.gd — pause support

**Files:**
- Modify: `scripts/WaveManager.gd`

**What:** Add `_paused: bool` flag and `set_paused(v)` method. Check the flag inside `_spawn_wave` before each enemy spawn so an in-flight coroutine terminates cleanly. Also reset `_paused` in `reset()`.

- [ ] **Step 1: Add `_paused` var after `_enemies_alive`**

Find:
```gdscript
var current_wave: int = 0
var _enemies_alive: int = 0
```

Replace with:
```gdscript
var current_wave: int = 0
var _enemies_alive: int = 0
var _paused: bool = false
```

- [ ] **Step 2: Add `set_paused` method**

Add after the signal declarations (or after `reset()`):
```gdscript
func set_paused(v: bool) -> void:
	_paused = v
```

- [ ] **Step 3: Add pause check inside `_spawn_wave`**

Find:
```gdscript
	for group in wave_data["groups"]:
		for i in group["count"]:
			_spawn_enemy(group["type"])
			if group["interval"] > 0.0:
				await get_tree().create_timer(group["interval"]).timeout
				if not is_instance_valid(self):
					return
```

Replace with:
```gdscript
	for group in wave_data["groups"]:
		for i in group["count"]:
			if _paused:
				return   # abandon in-flight coroutine on pause
			_spawn_enemy(group["type"])
			if group["interval"] > 0.0:
				await get_tree().create_timer(group["interval"]).timeout
				if not is_instance_valid(self):
					return
```

- [ ] **Step 4: Reset `_paused` in `reset()`**

Find:
```gdscript
func reset() -> void:
	current_wave = 0
	_enemies_alive = 0
```

Replace with:
```gdscript
func reset() -> void:
	current_wave = 0
	_enemies_alive = 0
	_paused = false
```

> **Note on `_enemies_alive` stale state:** When `_paused` causes the spawn coroutine to return early, some enemies that were never spawned are still counted in `_enemies_alive` (via the group count). This means `_check_wave_complete` may never fire for the abandoned wave. This is acceptable: the game-over state from Task 6 shows a restart button, and `_restart_td()` calls `wave_manager.reset()` which resets `_enemies_alive = 0`. No fix needed here.

- [ ] **Step 5: Run project (F5), confirm no errors**

Expected: Clean Output. Waves still work normally.

- [ ] **Step 6: Commit**

```bash
git add scripts/WaveManager.gd
git commit -m "feat: WaveManager pause support — _paused flag + set_paused()"
```

---

### Task 6: TowerDefense.gd — game-over state

**Files:**
- Modify: `scripts/TowerDefense.gd`

**What:** Add `_td_game_over: bool`. Guard `_on_enemy_reached_exit` against re-entry. Replace the current `_game_over()` with one that pauses enemies, stops tower timers, pauses WaveManager, and shows a new overlay ("基地淪陷！") with a conditional bomb button and a restart button. Update `_restart_td()` to reset the flag, call `GameManager.reset()`, and call `wave_manager.set_paused(false)`.

- [ ] **Step 1: Add `_td_game_over` var near other state vars**

After `var _wave_launching: bool = false` add:
```gdscript
var _td_game_over: bool = false
```

- [ ] **Step 2: Replace `_on_enemy_reached_exit`**

Find:
```gdscript
func _on_enemy_reached_exit() -> void:
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		_game_over()
```

Replace with:
```gdscript
func _on_enemy_reached_exit() -> void:
	if _td_game_over:   # prevent double-trigger from simultaneous exits
		return
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		_game_over()
```

- [ ] **Step 3: Add `_pause_all_enemies` and `_stop_all_tower_timers` helpers**

Add these two methods (e.g. just before `_game_over`):
```gdscript
func _pause_all_enemies() -> void:
	for e in enemy_container.get_children():
		if e is Enemy:
			e.set_physics_process(false)

func _stop_all_tower_timers() -> void:
	for tower in tower_container.get_children():
		if tower is Tower:
			tower.get_node("AttackTimer").stop()
```

- [ ] **Step 4: Replace `_game_over()`**

Find and replace the entire `_game_over()` function:

```gdscript
func _game_over() -> void:
	_td_game_over = true
	wave_button.disabled = true
	_pause_all_enemies()
	_stop_all_tower_timers()
	wave_manager.set_paused(true)

	var overlay := ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.custom_minimum_size = Vector2(220, 0)
	overlay.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var title := Label.new()
	title.text = "💀 基地淪陷！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "所有敵人暫停移動"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	# Bomb button — only shown when player has bombs
	if GameManager.bomb_count > 0:
		var bomb_btn := Button.new()
		bomb_btn.name = "BombBtn"
		bomb_btn.text = "💣 投放炸彈 (×%d)" % GameManager.bomb_count
		bomb_btn.pressed.connect(func():
			_on_bomb_aoe_requested(Vector2.ZERO)
			# Refresh or hide button after use
			if GameManager.bomb_count <= 0:
				bomb_btn.queue_free()
			else:
				bomb_btn.text = "💣 投放炸彈 (×%d)" % GameManager.bomb_count
		)
		panel.add_child(bomb_btn)

	var retry_btn := Button.new()
	retry_btn.text = "↺ 重新開始"
	retry_btn.pressed.connect(_restart_td)
	panel.add_child(retry_btn)
```

- [ ] **Step 5: Update `_restart_td()`**

Find `_restart_td()` and add the new lines at the top:

```gdscript
func _restart_td() -> void:
	_td_game_over = false
	wave_manager.set_paused(false)
	GameManager.reset()   # restores gold to STARTING_GOLD, resets bomb_count mirror
	lives = MAX_LIVES
	lives_label.text = "Lives: %d" % lives
	wave_button.disabled = false
	wave_button.text = "Start Wave 1"
	wave_manager.reset()
	# Clear all enemies
	for child in enemy_container.get_children():
		child.queue_free()
	# Clear all towers and reset grid
	for child in tower_container.get_children():
		child.queue_free()
	_init_grid()
	# Remove game-over overlay
	var go_overlay := get_node_or_null("GameOverOverlay")
	if go_overlay:
		go_overlay.queue_free()
	_wave_countdown_active = false
	_wave_launching = false
```

- [ ] **Step 6: Run project (F5), trigger game-over**

Note: `MAX_LIVES` is a `const` — to test quickly, temporarily add `lives = 1` as the **first line** of `_ready()` (after the `await`), run, then remove it before committing.

One enemy reaching the exit should trigger the "基地淪陷！" overlay. Verify:
- Enemies freeze (stop moving)
- Wave stops spawning
- Bomb button appears if `GameManager.bomb_count > 0` (requires having used bombs in 2048)
- Restart button clears overlay, resets gold to 100, clears enemies

Note: `_restart_td()` does not call `_setup_wave_manager()` — this is intentional. Waypoints don't change between restarts; `wave_manager.reset()` suffices to reset wave state.

Remove the temporary `lives = 1` line before committing.

- [ ] **Step 7: Commit**

```bash
git add scripts/TowerDefense.gd
git commit -m "feat: TD game-over state — pause enemies/towers/waves, bomb button, restart"
```

---

### Task 7: TowerDefense.gd — corner-only tower slots + bottom bar redesign

**Files:**
- Modify: `scripts/TowerDefense.gd`

**What:**
1. Add `_corner_slots: Array[Vector2i]` and `_slot_towers: Dictionary`, populated from waypoints 1–4.
2. Replace free-placement click logic with corner-slot-only logic.
3. Add `_show_tower_type_selection(cell)` panel.
4. Guard sell button to not clear `_blocked` on corner cells.
5. Remove `_build_tower_palette()` and `_on_tower_type_selected()`.
6. Remove `_selected_tower_type` var (no longer needed).
7. Replace bottom bar palette with "Tech Tree" placeholder button.

- [ ] **Step 1: Add corner-slot vars near other state vars**

After `var _td_game_over: bool = false` add:
```gdscript
var _corner_slots: Array[Vector2i] = []
var _slot_towers: Dictionary = {}      # Vector2i → Tower
var _type_select_panel: PanelContainer = null
```

Remove the `var _selected_tower_type: int = 0` line (no longer needed).

**Important:** Do not run the project until Step 7. Steps 1–6 remove `_selected_tower_type` and delete the referencing methods (`_build_tower_palette`, `_on_tower_type_selected`, the old `_input`) incrementally. The project will have parse errors until all removals are complete.

- [ ] **Step 2: Populate `_corner_slots` at the end of `_build_world_waypoints`**

At the end of `_build_world_waypoints()` add:
```gdscript
	# Corner slots = turning points (indices 1–4 of WAYPOINTS_NORMALIZED)
	_corner_slots.clear()
	_slot_towers.clear()
	for i in range(1, 5):   # indices 1, 2, 3, 4
		var corner_cell := world_to_cell(_world_waypoints[i])
		_corner_slots.append(corner_cell)
```

- [ ] **Step 3: Rewrite `_input` to use corner-slot logic only**

Find the entire `_input(event)` function and replace it:
```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not get_global_rect().has_point(event.position):
			return
		var local_pos := get_local_mouse_position()
		var cell := world_to_cell(local_pos)
		if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
			return
		if cell in _corner_slots:
			if _slot_towers.get(cell) == null:
				_close_tower_info()
				_show_tower_type_selection(cell)
			else:
				_close_type_selection()
				_show_tower_info(_slot_towers[cell])
		else:
			_close_tower_info()
			_close_type_selection()
```

- [ ] **Step 4: Add `_show_tower_type_selection`, `_close_type_selection`, `_place_tower_at_slot` methods**

Add these methods (e.g. after `_close_tower_info`):
```gdscript
func _show_tower_type_selection(cell: Vector2i) -> void:
	_close_type_selection()
	_type_select_panel = PanelContainer.new()
	_type_select_panel.custom_minimum_size = Vector2(150, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_type_select_panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚔ 選擇塔類型"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var tower_defs := [
		["× Basic",   Tower.TowerType.BASIC],
		["🎯 Sniper",  Tower.TowerType.SNIPER],
		["💥 Splash", Tower.TowerType.SPLASH],
		["❄ Slow",    Tower.TowerType.SLOW],
		["⚡ Laser",  Tower.TowerType.LASER],
	]
	for td in tower_defs:
		var cost: int = TowerData.STATS[td[1]][1]["cost"]
		var btn := Button.new()
		btn.text = "%s  %dg" % [td[0], cost]
		btn.pressed.connect(func(): _place_tower_at_slot(cell, td[1]))
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "✕ 取消"
	cancel_btn.pressed.connect(_close_type_selection)
	vbox.add_child(cancel_btn)

	# Position near click, clamped next frame
	var world_pos := cell_to_world(cell)
	_type_select_panel.position = world_pos + Vector2(10, -60)
	add_child(_type_select_panel)
	await get_tree().process_frame
	if not is_instance_valid(_type_select_panel):
		return
	_type_select_panel.position.x = clamp(_type_select_panel.position.x, 0.0, size.x - _type_select_panel.size.x)
	_type_select_panel.position.y = clamp(_type_select_panel.position.y, 0.0, size.y - _type_select_panel.size.y)


func _close_type_selection() -> void:
	if is_instance_valid(_type_select_panel):
		_type_select_panel.queue_free()
	_type_select_panel = null


func _place_tower_at_slot(cell: Vector2i, type_val: Tower.TowerType) -> void:
	var cost: int = TowerData.STATS[type_val][1]["cost"]
	if not GameManager.spend_gold(cost):
		_close_type_selection()
		return
	_close_type_selection()
	_place_tower(cell, type_val as int)
	_slot_towers[cell] = _grid[cell.y][cell.x]
```

- [ ] **Step 5: Guard the sell button — corner cells must not clear `_blocked`**

In `_show_tower_info`, find the sell button's `pressed` lambda:
```gdscript
	sell_btn.pressed.connect(func():
		GameManager.earn_gold(original_cost / 2)
		_grid[tower.grid_cell.y][tower.grid_cell.x] = null
		_blocked[tower.grid_cell.y][tower.grid_cell.x] = false
		tower.queue_free()
		_close_tower_info()
	)
```

Replace with:
```gdscript
	sell_btn.pressed.connect(func():
		GameManager.earn_gold(original_cost / 2)
		var sell_cell := tower.grid_cell
		_grid[sell_cell.y][sell_cell.x] = null
		# Corner cells are permanently PATH-blocked; do not clear _blocked for them
		if not (sell_cell in _corner_slots):
			_blocked[sell_cell.y][sell_cell.x] = false
		_slot_towers.erase(sell_cell)
		tower.queue_free()
		_close_tower_info()
	)
```

- [ ] **Step 6: Replace `_build_tower_palette()` with a Tech Tree placeholder**

Find the entire `_build_tower_palette()` method and `_on_tower_type_selected()` method and delete them both.

Then find the call to `_build_tower_palette()` in `_ready()` and replace it with:
```gdscript
	_build_bottom_bar()
```

Add the new method:
```gdscript
func _build_bottom_bar() -> void:
	# Tech Tree placeholder — future skill upgrades
	var tech_btn := Button.new()
	tech_btn.text = "🔬 Tech Tree"
	tech_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	tech_btn.pressed.connect(func():
		# Placeholder: show "Coming Soon" label briefly
		tech_btn.text = "🔬 Coming Soon..."
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(tech_btn):
			tech_btn.text = "🔬 Tech Tree"
	)
	var bottom_bar := $UI/BottomBar
	bottom_bar.add_child(tech_btn)
	bottom_bar.move_child(tech_btn, 0)   # place before WaveButton
```

- [ ] **Step 7: Run project (F5), full integration test**

Check:
1. TD grid visible, path rendered
2. Clicking a corner cell (blue circle location) shows the 5-tower selection panel
3. Choosing a tower type with enough gold places a tower and closes the panel
4. Clicking placed tower shows upgrade/sell panel
5. Selling tower removes it; corner cell shows empty slot again
6. Clicking non-slot cells does nothing
7. Bottom bar shows only "🔬 Tech Tree" and "▶ Start Wave 1"
8. No errors in Output

- [ ] **Step 8: Commit**

```bash
git add scripts/TowerDefense.gd
git commit -m "feat: corner-only tower slots, type-select panel, Tech Tree placeholder"
```

---

## Final verification

- [ ] **Full play-through check**

1. Start game. Verify TD starts with 100 gold.
2. Play 2048, accumulate score — gold increases at every 200-point milestone.
3. Build towers at corner slots.
4. Let enemies through until lives = 0 — "基地淪陷！" overlay appears, enemies freeze.
5. If 2048 has bomb, press bomb — AOE flash fires on TD, bomb count decrements.
6. Press "↺ 重新開始" — gold resets to 100, grid clears, wave counter resets.
7. Confirm both panels are equal-width with aligned top/bottom bars.

- [ ] **Commit final state**

```bash
git add -A
git commit -m "chore: TD overhaul complete — grid 64x64, corner slots, game-over, 100 start gold"
```
