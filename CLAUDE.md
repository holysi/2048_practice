# CLAUDE.md — 2048 Godot 4 Project

## Project Structure
- `scripts/Game.gd` — all game logic (board, moves, spawn, bomb, overlays)
- `scripts/SaveData.gd` — level definitions (LEVELS const), save/load
- `scripts/Tile.gd` — per-tile display + animations
- `scenes/Game.tscn` — scene tree (UI/TopBar, UI/BottomBar, BoardContainer, TileContainer, MergeAudio)
- `scenes/LevelSelect.tscn` — level selection screen

## Godot 4 Gotchas
- **Anchor preset ordering**: always call `$UI.add_child(node)` BEFORE `node.set_anchors_preset(...)` — anchors resolve from parent size, which requires the node to be in the scene tree
- **True centering**: `PRESET_CENTER` alone is not enough; also set `grow_horizontal = GROW_DIRECTION_BOTH` and `grow_vertical = GROW_DIRECTION_BOTH`
- **Tween pivot**: scaling a node via Tween expands from `pivot_offset = (0,0)` by default; set `node.pivot_offset = node.size / 2.0` before tweening for center-origin scale
- **AudioStreamGenerator**: `get_stream_playback()` returns `null` after `stop()` — call `merge_audio.play()` in `restart()` to restore audio after win/game-over
- **`.tscn` manual edits**: delete the *entire* node block (all property lines) — orphaned properties cause parse errors

## Code Style
- Indentation: **tabs** (enforced by Godot editor)
- Variable declarations: use `:=` (walrus) for type inference
- Node paths: use `@onready var foo = $Path/To/Node` — never `get_node()` in hot paths
- Forward-compatible node access: use `get_node_or_null("NodeName")` when a node may not exist yet

## AudioStreamGenerator Pattern
- Shared `MergeAudio` (AudioStreamPlayer) node reused for all tones — call `playback.clear_buffer()` before writing new frames
- Sample rate: `AUDIO_SAMPLE_RATE = 22050`, buffer_length = 0.1
- Bomb tone: 80 Hz sawtooth, 0.3 s; Merge tone: sine wave, pitch ∝ log(value)

## Level System
- Levels defined in `SaveData.LEVELS` — add `spawn_pool` + `spawn_weights` (must sum to 100) per level
- Weighted spawn picker: `randi() % 100`, accumulate weights, return first bucket where roll < cumulative

## Bomb Item
- `bomb_count` state in `Game.gd`; `_update_bomb_ui()` is the single source of truth for button state
- Award: +2 per move where any merge reaches ≥128 (capped once per move via `bomb_earned` flag)
- Use: shuffle non-zero tile values, clear 2 smallest, clear undo history
