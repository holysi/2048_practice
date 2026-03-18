# Overlay Centering Fix — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the win and game-over overlay panels render at the centre of the screen instead of the top-left corner.

**Architecture:** Each panel VBoxContainer is reparented from `$UI` (the CanvasLayer) to its own overlay ColorRect. Because the ColorRect already uses `PRESET_FULL_RECT`, its size is known when the child panel calls `set_anchors_preset(PRESET_CENTER)`, resolving the anchor correctly.

**Tech Stack:** GDScript / Godot 4

---

## Chunk 1: Fix overlay panel parenting

### Task 1: Fix `_show_win()` panel parenting

**Files:**
- Modify: `scripts/Game.gd:416`

- [ ] **Step 1: Change the parent of the win panel from `$UI` to `overlay`**

  In `_show_win()`, line 416, change:
  ```gdscript
  $UI.add_child(panel)
  ```
  to:
  ```gdscript
  overlay.add_child(panel)
  ```

- [ ] **Step 2: Manual smoke-test**

  Run the game, reach the win condition (or use Godot's debugger to call `_show_win()` directly).
  Expected: dark overlay covers the screen; 🎉 通關！ panel appears centred.

---

### Task 2: Fix `_show_game_over()` panel parenting

**Files:**
- Modify: `scripts/Game.gd:482`

- [ ] **Step 1: Change the parent of the game-over panel from `$UI` to `overlay`**

  In `_show_game_over()`, line 482, change:
  ```gdscript
  $UI.add_child(panel)
  ```
  to:
  ```gdscript
  overlay.add_child(panel)
  ```

- [ ] **Step 2: Manual smoke-test**

  Fill the board with tiles that leave no valid moves (or temporarily set `bomb_count = 0` and trigger game-over).
  Expected: dark overlay covers the screen; 遊戲結束！ panel appears centred.

---

### Task 3: Commit

- [ ] **Commit the fix**

  ```bash
  git add scripts/Game.gd
  git commit -m "fix: centre win and game-over overlay panels"
  ```
