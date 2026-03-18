# Overlay Centering Fix — Design Spec

**Date:** 2026-03-18
**Status:** Approved

## Problem

The win overlay panel (`_show_win`) and game-over overlay panel (`_show_game_over`) in `scripts/Game.gd` render at the top-left corner (0, 0) instead of the screen centre.

**Root cause:** Both panels are added as direct children of `$UI` (a `CanvasLayer`) and then positioned with `set_anchors_preset(PRESET_CENTER)`. At the moment `add_child` is called, the VBoxContainer's size has not been resolved yet, so the anchor-based offset calculates to zero and the node stays at origin.

## Design

Make each panel a **child of its own overlay ColorRect** instead of a sibling in `$UI`.

The overlay ColorRect already uses `PRESET_FULL_RECT` and is guaranteed to fill the viewport. Anchoring a child panel to `PRESET_CENTER` inside a known-size parent resolves correctly.

```
Before:
  $UI (CanvasLayer)
    ├── overlay (ColorRect, PRESET_FULL_RECT)  ← covers screen ✓
    └── panel  (VBoxContainer, PRESET_CENTER)  ← parent size unknown → (0,0) ✗

After:
  $UI (CanvasLayer)
    └── overlay (ColorRect, PRESET_FULL_RECT)  ← covers screen ✓
          └── panel (VBoxContainer, PRESET_CENTER) ← parent size known → centred ✓
```

### Changes

| File | Function | Change |
|------|----------|--------|
| `scripts/Game.gd` | `_show_win()` | `$UI.add_child(panel)` → `overlay.add_child(panel)` |
| `scripts/Game.gd` | `_show_game_over()` | `$UI.add_child(panel)` → `overlay.add_child(panel)` |

Two one-line edits. No new nodes, no logic changes.

## Constraints

- Existing `grow_horizontal = GROW_DIRECTION_BOTH` and `grow_vertical = GROW_DIRECTION_BOTH` are kept — they ensure the panel expands symmetrically from the anchor centre point.
- The overlay `ColorRect` must be added to `$UI` **before** the panel is added to it (already the case).
