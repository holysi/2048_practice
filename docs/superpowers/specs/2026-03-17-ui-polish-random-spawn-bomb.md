# Spec: UI Polish, Random Spawn, and Bomb Item
Date: 2026-03-17

## Overview

Four improvements to the Godot 4 2048 game:
1. Remove the static "2048" game-title Label from the TopBar
2. Center end-game overlays (win / game-over) properly on screen
3. From Lv.3+, allow higher-value tiles to spawn (increasing randomness)
4. Add a Bomb item: earn by merging to ≥128, use to shuffle + clear the board

---

## Feature 1: Remove "2048" Title Label

**Problem:** A static Label displaying "2048" sits in the top-left TopBar. It is large, takes space, and conveys no useful information to the player.

**Fix:** Delete the Label node (or equivalent node with text "2048") from `Game.tscn`'s TopBar. The ScoreBox (SCORE label + numeric value) remains.

---

## Feature 2: Center End-Game Overlays

**Problem:** `_show_win()` and `_show_game_over()` position a Label with `PRESET_CENTER`, but the Label's intrinsic size is unconstrained, so text drifts toward a corner rather than appearing at screen center.

**Fix:** Replace bare Labels with a `VBoxContainer` as the content panel, centered on screen using `PRESET_CENTER` with `grow_horizontal = GROW_DIRECTION_BOTH` and `grow_vertical = GROW_DIRECTION_BOTH`.

### Win Screen Layout
```
[WinPanel — VBoxContainer, centered, ~80% width]
  [TitleLabel]     "🎉 通關！"                   font_size=28, center-aligned
  [InfoLabel]      "分數：X　時間：Y 秒"            font_size=20, center-aligned
  [ButtonRow]      HBoxContainer, alignment=CENTER
    [再玩一次]  [下一關]  [返回選關]
```

### Game-Over Screen Layout
```
[GameOverPanel — VBoxContainer, centered, ~80% width]
  [TitleLabel]     "遊戲結束！"                   font_size=28, center-aligned
  [InfoLabel]      "最終分數：X\n按「重新開始」繼續"  font_size=20, center-aligned
```

All text is white; background overlay stays full-screen dark (`ColorRect`, color `Color(0,0,0,0.7)`).

---

## Feature 3: Level-Scaled Random Spawn Pool

**Problem:** All levels currently spawn only 2 (90%) or 4 (10%), providing no scaling challenge.

**Design:** From Lv.3 onwards, higher-value tiles can spawn. Weights sum to 100.

| Level | Target | Pool         | Weights (%)         |
|-------|--------|--------------|---------------------|
| Lv.1  | 128    | [2, 4]       | [90, 10]            |
| Lv.2  | 256    | [2, 4]       | [90, 10]            |
| Lv.3  | 512    | [2, 4, 8, 16]| [50, 25, 15, 10]    |
| Lv.4  | 1024   | [2, 4, 8, 16, 32] | [50, 25, 12, 8, 5] |
| Lv.5  | 2048   | [2, 4, 8, 16, 32, 64] | [45, 25, 12, 8, 6, 4] |

**Implementation:**
- Add `"spawn_pool"` and `"spawn_weights"` arrays to each entry in `SaveData.LEVELS`.
- Rewrite `spawn_tile()` in `Game.gd` to use weighted random selection from the pool for the current level.
- Weighted selection: accumulate weights, pick `randi() % 100`, find the matching bucket.

---

## Feature 4: Bomb Item

### Earning Bombs
- Whenever a move results in any tile merging to a value **≥ 128**, award **+2 bombs**.
- Award is capped at **once per move** (even if multiple merges qualify).
- Detection reuses the existing `pre_board` diff loop in `_try_move()`.
- Bomb count resets to 0 on `restart()` and is **not** persisted to save file.

### UI — TopBar (right side)

TopBar (HBoxContainer) gets a new right-aligned Button:

```
[ScoreBox — size_flags_horizontal = SIZE_EXPAND_FILL]   [BombButton "💣 ×N"]
```

- `BombButton` node added to `Game.tscn` TopBar.
- `@onready var bomb_button: Button = $UI/TopBar/BombButton`
- Button text: `"💣 ×%d" % bomb_count`
- Button disabled when `bomb_count == 0`.
- Button pressed → `_use_bomb()`.

### Bomb Use Effect

`_use_bomb()` performs:
1. Guard: return if `bomb_count == 0` or `_win_shown`.
2. `bomb_count -= 1`, update button UI.
3. **Shuffle:** collect all non-zero values from `board`, shuffle the array (`values.shuffle()`), redistribute to cells that previously held non-zero values (random permutation of positions).
4. **Clear 2:** find the 2 cells with the smallest values after shuffle; set them to 0.
5. **Animation:** `_play_bomb_animation()` — tween the `BoardContainer` scale 1.0 → 1.05 → 1.0 over 0.3 s (`TRANS_SINE`), plus a full-screen white `ColorRect` that fades from alpha 0.6 → 0.0 over 0.4 s.
6. **Sound:** `_play_bomb_tone()` — `AudioStreamGenerator` produces an 80 Hz sawtooth wave with amplitude envelope decaying over 0.3 s (300 ms, 22050 Hz sample rate).
7. `_update_display()` — refresh tile nodes.
8. Clear history (undo stack is invalid after shuffle).

### Sawtooth Wave Formula
```
sample[i] = (2.0 * fmod(freq * t, 1.0) - 1.0) * amp(t)
amp(t) = 0.4 * (1.0 - t / dur)
```

### Files Changed

| File | Change |
|------|--------|
| `scripts/SaveData.gd` | Add `spawn_pool` + `spawn_weights` to `LEVELS` |
| `scripts/Game.gd` | Rewrite `spawn_tile()`; add bomb state, `_use_bomb()`, `_play_bomb_animation()`, `_play_bomb_tone()`, update `_try_move()` and `_show_win()` / `_show_game_over()` |
| `scenes/Game.tscn` | Remove 2048 Label; add `BombButton` to TopBar |

---

## Non-Goals
- Bomb count is not shown on the level-select screen.
- No visual indicator of which tiles will be cleared before use.
- No limit on maximum bombs held.
