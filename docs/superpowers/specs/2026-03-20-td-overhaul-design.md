# TD Overhaul Design — 2026-03-20

## Summary

Six changes to the hybrid 2048 + Tower Defense game:

1. Symmetric panel layout (equal-width, aligned bars)
2. Grid redesign: 10×14 → 64×64 cells
3. Corner-only tower slots
4. TD game-over state (lives=0 → pause, bomb still usable)
5. Starting gold = 100
6. Enemy coordinate fix (local → global waypoints)

---

## 1. Symmetric Panel Layout

### Panel dimensions

| Item | 2048 Panel | TD Panel |
|------|-----------|----------|
| Panel width | 50% screen width | 50% screen width |
| Top info bar | `UI_BAR_H = 32` px | `UI_BAR_H = 32` px |
| Game area | 320 × 320 px | 320 × 320 px |
| Bottom bar | `UI_BAR_H = 32` px | `UI_BAR_H = 32` px |

Both game areas are identical pixel dimensions — visually symmetric.

### HybridGame.tscn split

```
HybridGame (Control, full screen)
├── LeftPanel  (anchor right=0.5)  ← 2048
└── RightPanel (anchor left=0.5)   ← TowerDefense
```

Top/bottom bar heights must use the same constant in both scenes.
TowerDefense computes `cell_size = min(game_area_w, game_area_h) / 64.0` after layout.

---

## 2. Grid Redesign: 64 × 64

### Constants changed in TowerDefense.gd

```gdscript
const GRID_COLS: int = 64
const GRID_ROWS: int = 64
```

Cell size is computed after layout (not a constant):

```gdscript
var cell_size: float   # set in _ready after await process_frame
var grid_offset: Vector2  # centres grid in panel if aspect differs

func _compute_cell_size() -> void:
    cell_size = min(size.x / GRID_COLS, size.y / GRID_ROWS)
    grid_offset = (size - Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)) / 2.0
```

### Grid helper rewrites

The old helpers used `size / Vector2(GRID_COLS, GRID_ROWS)` (non-uniform per-axis cell size).
Replace with the uniform scalar `cell_size` + `grid_offset`:

```gdscript
func cell_to_world(cell: Vector2i) -> Vector2:
    return grid_offset + Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size

func world_to_cell(world_pos: Vector2) -> Vector2i:
    var local := world_pos - grid_offset
    return Vector2i(int(local.x / cell_size), int(local.y / cell_size))

# _is_cell_on_path threshold — unchanged formula, now uses scalar cell_size:
# if _dist_point_to_segment(cell_center, a, b) < cell_size * 0.6
```

All other helpers (`_dist_point_to_segment`, `_build_grid`, etc.) use `cell_size` (float) everywhere `cell_size.x` previously appeared.

### New waypoints (64×64 normalised)

```gdscript
const WAYPOINTS_NORMALIZED: Array = [
    Vector2(1.0,  0.25),   # entry — right edge
    Vector2(0.69, 0.25),   # corner 1
    Vector2(0.69, 0.68),   # corner 2
    Vector2(0.31, 0.68),   # corner 3
    Vector2(0.31, 0.25),   # corner 4
    Vector2(0.0,  0.25),   # exit  — left edge (base)
]
```

These are the same normalised values as before; the denser grid simply makes the path wider (more cells marked PATH).
Path width stays at 1 cell (same logic — `_build_grid` marks cells along straight segments).

---

## 3. Corner-Only Tower Slots

### Design

- Exactly **4 tower slots**: the 4 turning points of the path (WAYPOINTS_NORMALIZED indices 1–4).
- No free placement elsewhere.
- Visual: empty slot = blue dashed circle drawn in `_draw()` or a small Sprite/ColorRect overlay.

### Cell classification

No new enum value. Use a **separate array** checked in the click handler:

```gdscript
var _corner_slots: Array[Vector2i] = []   # computed in _build_world_waypoints
var _slot_towers:  Dictionary = {}        # cell → Tower node (or null)
```

`_blocked` is unchanged — corner cells are PATH-blocked (enemies walk through them).
`_corner_slots` is checked *in addition* in `_on_grid_click`.

### Sell logic — corner cells must not clear `_blocked`

The existing sell handler clears `_blocked[cell] = false` after removing a tower.
Corner cells must remain blocked (enemies traverse them) regardless of tower presence.
Add a guard in the sell callback:

```gdscript
# in _show_tower_info sell button pressed:
_slot_towers.erase(cell)          # remove from slot tracking
_grid[cell.y][cell.x] = null
# DO NOT clear _blocked for corner cells — they stay PATH-blocked
if not (cell in _corner_slots):
    _blocked[cell.y][cell.x] = false
tower.queue_free()
```

### Click logic

```gdscript
func _on_grid_click(cell: Vector2i) -> void:
    if cell in _corner_slots:
        if _slot_towers.get(cell) == null:
            _show_tower_type_selection(cell)
        else:
            _show_tower_info(_slot_towers[cell])
    # all other cells: no response
```

### `_show_tower_type_selection(cell)`

Floating PanelContainer (child of TowerDefense, centered):

```
⚔ 選擇塔類型
× Basic       50g
🎯 Sniper     80g
💥 Splash    100g
❄ Slow        70g
⚡ Laser      120g
✕ 取消
```

On type selected:
1. Check `GameManager.spend_gold(cost)` — if false, show "Gold insufficient", return.
2. Instantiate tower → `_slot_towers[cell] = tower`.
3. Close panel.

Remove old bottom-bar tower-type buttons and all free-placement code.

---

## 4. TD Game-Over State

### Trigger

`_on_enemy_reached_exit()` — guard against re-entry:

```gdscript
func _on_enemy_reached_exit() -> void:
    if _td_game_over:   # ← prevents double-trigger when multiple enemies
        return          #   reach the exit on the same frame
    lives -= 1
    _update_lives_label()
    if lives <= 0:
        _game_over()
```

### `_game_over()` sequence

```gdscript
var _td_game_over: bool = false

func _game_over() -> void:
    _td_game_over = true
    _pause_all_enemies()         # set_physics_process(false) on each enemy
    wave_manager.set_paused(true)
    _stop_all_tower_timers()     # stop attack timers so towers don't fire
    _show_game_over_overlay()
```

### Pausing enemies

```gdscript
func _pause_all_enemies() -> void:
    for e in enemy_container.get_children():
        if e is Enemy:
            e.set_physics_process(false)
```

### Pausing WaveManager

Add `set_paused(v: bool)` to WaveManager:

```gdscript
var _paused: bool = false

func set_paused(v: bool) -> void:
    _paused = v

# Inside _spawn_wave coroutine, check before each spawn:
func _spawn_wave(...) -> void:
    for group in wave_data.groups:
        for i in group.count:
            if _paused:
                return          # abandon in-flight wave coroutine
            _spawn_enemy(...)
            await get_tree().create_timer(group.interval).timeout
```

This cleanly terminates any in-flight `_spawn_wave` coroutine immediately on the next iteration.

### Stopping tower timers

```gdscript
func _stop_all_tower_timers() -> void:
    for tower in tower_container.get_children():
        if tower is Tower:
            tower.get_node("AttackTimer").stop()
```

Tower does **not** check `is_game_over()` at runtime — stopping the timer is simpler and has no per-frame overhead.

### Game-over overlay

Dark semi-transparent PanelContainer, centered:

```
💀 基地淪陷！
所有敵人暫停移動

[💣 投放炸彈 (×N)]   ← only when bomb_count > 0
[↺ 重新開始]
```

Bomb count is read from **`GameManager.bomb_count`** — add a forwarded property to GameManager:

```gdscript
# GameManager.gd
var _bomb_count: int = 0          # backing variable (must be declared)
var bomb_count: int:
    get: return _bomb_count
    set(v): _bomb_count = v
```

`Game.gd` sets `GameManager.bomb_count = bomb_count` whenever `bomb_count` changes
(in `_update_bomb_ui()` and `_use_bomb()`).

The overlay button calls `_on_bomb_aoe_requested(Vector2.ZERO)` and refreshes the button label/visibility. Game-over state is **not cleared** by bomb use.

### Restart

`_restart_td()` gains:

```gdscript
func _restart_td() -> void:
    _td_game_over = false
    wave_manager.set_paused(false)
    GameManager.reset()   # ← restores gold to STARTING_GOLD = 100
    # ... existing reset logic (removes overlay, clears enemies, resets lives)
```

Calling `GameManager.reset()` resets gold to 100 on each TD restart (consistent with a fresh game start).

---

## 5. Starting Gold = 100

```gdscript
# GameManager.gd
const STARTING_GOLD: int = 100
var gold: int = STARTING_GOLD

func reset() -> void:
    gold = STARTING_GOLD
    emit_signal("gold_changed", gold)
```

---

## 6. Enemy Coordinate Fix

`_setup_wave_manager()` already fixed (converts local waypoints → global):

```gdscript
var origin: Vector2 = get_global_rect().position
var global_wps: Array = []
for wp in _world_waypoints:
    global_wps.append(wp + origin)
wave_manager.waypoints = global_wps
```

No additional changes needed here.

---

## Files Modified

| File | Changes |
|------|---------|
| `scenes/HybridGame.tscn` | 50/50 anchor split; `UI_BAR_H = 32` on both panels |
| `scripts/TowerDefense.gd` | GRID 64×64; `cell_size`/`grid_offset` computed at runtime; corner slots; game-over state; bottom bar; stop tower timers |
| `scripts/WaveManager.gd` | `set_paused(v)` + `_paused` check in `_spawn_wave` |
| `scripts/GameManager.gd` | `STARTING_GOLD = 100`; forwarded `bomb_count` property |
| `scripts/Game.gd` | Sync `bomb_count` → `GameManager.bomb_count` in `_update_bomb_ui()` |

---

## Out of Scope

- Tech Tree implementation (bottom-bar button is placeholder only)
- More than 4 tower slots
- Wave survival bonuses
