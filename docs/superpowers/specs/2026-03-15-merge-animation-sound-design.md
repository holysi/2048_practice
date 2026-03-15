# Design Spec: Merge Animation & Procedural Sound (+ Win Screen Fix)
Date: 2026-03-15

## Scope
Three concerns addressed together:
1. **Bug fix** — Win screen buttons not appearing after level completion
2. **Merge animation** — Visual feedback when tiles merge; intensity scales with result value
3. **Procedural sound** — Synthesised sine-wave tone on merge; pitch scales with result value

---

## 1. Win Screen Bug Fix

### Root Cause
In `_show_win()` (Game.gd), `set_anchors_preset(Control.PRESET_FULL_RECT)` and manual
anchor properties are set **before** nodes are added to the scene tree.
Godot 4 can only resolve anchor-to-pixel conversions once a node knows its parent's size.
Calling anchor setters on an orphan node produces undefined rect results (typically 0×0),
making nodes invisible.

### Fix
In every dynamic node construction block inside `_show_win()` and `_show_game_over()`:
- Call `$UI.add_child(node)` **first**
- Call `set_anchors_preset()` or set `anchor_*` properties **after**

No other structural changes needed.

---

## 2. Merge Animation

### Location
`scripts/Tile.gd` — two new public methods.

### Methods

#### `animate_spawn() -> void`
Called when a new tile is placed on the board.
- Set `scale = Vector2.ZERO` immediately
- Tween `scale` → `Vector2.ONE` in `0.12 s`
- Easing: `EASE_OUT`, `TRANS_BACK` (springy overshoot)

#### `animate_merge(value: int) -> void`
Called on a tile cell that received a merge result.
- Compute **intensity** `t = log(float(value)) / log(2048.0)` → range [0, 1]
- `peak_scale = lerp(1.10, 1.40, t)`  — 2→1.10×, 2048→1.40×
- `duration   = lerp(0.08, 0.20, t)` — 2→80 ms, 2048→200 ms
- Tween `scale` → `Vector2(peak, peak)` in `duration * 0.5`, then back to `Vector2.ONE` in `duration * 0.5`
- Both halves use `EASE_OUT` / `EASE_IN` for a smooth pop

If a tween is already running (rapid moves), kill it first and reset `scale` to `Vector2.ONE`
before starting the new tween.

### Integration in Game.gd

#### spawn_tile() return value
Change signature to `spawn_tile() -> Vector2i`.
Return `Vector2i(-1, -1)` when no empty cell; otherwise return the spawned `Vector2i(row, col)`.

#### _try_move() changes
```
1. var pre_board = _copy_board(board)
2. if move(direction):          # move() calls spawn_tile() internally
3.   var spawn_pos = _last_spawn   # tracked inside spawn_tile()
4.   _update_display()
5.   # Trigger merge animations
6.   for row in BOARD_SIZE:
7.     for col in BOARD_SIZE:
8.       if board[row][col] > pre_board[row][col] and board[row][col] > 0:
9.         tile_nodes[row][col].animate_merge(board[row][col])
10.  # Trigger spawn animation
11.  if spawn_pos != Vector2i(-1, -1):
12.    tile_nodes[spawn_pos.x][spawn_pos.y].animate_spawn()
13.  # Win / game-over checks (unchanged)
```

A new `var _last_spawn: Vector2i = Vector2i(-1, -1)` tracks the most recently spawned cell.

---

## 3. Procedural Sound

### Architecture
- One `AudioStreamPlayer` node added to `Game.tscn` as child of root (not UI), named `MergeAudio`
- `@onready var merge_audio: AudioStreamPlayer = $MergeAudio`
- The player's stream is an `AudioStreamGenerator` created at runtime with `mix_rate = 22050`
- Playback is obtained once in `_ready()` and reused

### Tone Parameters

| Parameter | Formula | Range |
|-----------|---------|-------|
| Frequency | `330.0 * pow(4.0, log(value) / log(2048.0))` | 330 Hz (value=2) → 1320 Hz (value=2048) |
| Duration  | `0.06 s` fixed | — |
| Waveform  | Sine | — |
| Envelope  | Linear fade-out `amplitude = 0.5 * (1.0 - t / duration)` | — |

### Method `_play_merge_tone(value: int) -> void`
```gdscript
func _play_merge_tone(value: int) -> void:
    var freq := 330.0 * pow(4.0, log(float(value)) / log(2048.0))
    var duration := 0.06
    var sample_rate := 22050.0
    var frames := int(sample_rate * duration)
    var playback := merge_audio.get_stream_playback() as AudioStreamGeneratorPlayback
    playback.clear_buffer()
    for i in frames:
        var t := float(i) / sample_rate
        var amp := 0.5 * (1.0 - t / duration)
        var sample := sin(TAU * freq * t) * amp
        playback.push_frame(Vector2(sample, sample))
```

Called from `_try_move()` after detecting a merge (any cell where `board[row][col] > pre_board[row][col]`).
Only one call per move (first detected merge), to avoid sound stacking.

### Setup in _ready()
```gdscript
var gen := AudioStreamGenerator.new()
gen.mix_rate = 22050.0
gen.buffer_length = 0.1  # slightly larger than max tone
merge_audio.stream = gen
merge_audio.play()  # must be playing to get playback object
```

---

## 4. Files Changed

| File | Change |
|------|--------|
| `scripts/Tile.gd` | Add `animate_spawn()`, `animate_merge(value)` |
| `scripts/Game.gd` | Fix win/gameover anchor order; add `_last_spawn`; change `spawn_tile()` return type; update `_try_move()`; add `_play_merge_tone(value)`; setup audio in `_ready()` |
| `scenes/Game.tscn` | Add `AudioStreamPlayer` node named `MergeAudio` |

---

## 5. Out of Scope
- Sound for tile spawn (kept silent to reduce noise)
- Volume control UI
- Win screen visual redesign (anchor fix is sufficient)
