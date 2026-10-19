---
name: match3-game-shell
description: >
  Game shell of the match-3 project: game modes, GameSession, mode switching,
  scene reload, pause menu, turn-manager hold, HUD-aware camera fit. Use when
  touching core/modes, game/game_root.gd, game/game_session.gd, view/menu,
  view/hud, or adding a mode or HUD element.
---

## Modes

- `GameMode` supplies `build_phases(ctx, level)`, `board_params(base, level)`, HUD visibility.
- `GameRoot.available_modes`: `InfiniteMode`, `BattleMode` "Battle", `BattleMode` "PvP".
- New mode: subclass `GameMode` only when the phase list differs; otherwise configure an existing mode.

## State

- `GameSession` (static vars): `params`, `mode_index`, `battle_level`. Survives scene reload. The only
  copy of each value; core receives them as parameters.

## Switching and reset

- `GameRoot.switch_mode(mode)`: same board, new `TurnManager`. When the board is busy, it calls
  `turn_manager.request_hold()` and applies on `held`.
- Reset, settings, next battle: `get_tree().reload_current_scene()`; unpause first.
- Cross-frame waits must be view-owned tweens (`create_tween().tween_interval`), never
  `SceneTree.create_timer` — timers survive reload and resume coroutines on freed objects.

## Menu

- `GameMenu` (`view/menu/`, built in code): ☰ / Esc, `get_tree().paused`, `PROCESS_MODE_ALWAYS`.
  Emits `mode_selected`, `editor_selected`, `settings_applied`, `reset_requested`, `quit_requested`.

## Orientation (mobile)

- `_fit_content_scale()`: portrait window → base size turned portrait (1080×1920); landscape keeps
  the project size. UI is never shrunk to a 1920-wide canvas on phones.
- Views branch on their own `size.y > size.x` (see `BattleView._apply_layout`): landscape = side
  columns, portrait = rows; compact cards (`CharacterCard.set_compact`).
- Docked HUD (`GameRoot._docked_hud()`: `ScoreHud`, `QuestHud`, `BattleView`) implements
  `hud_rects()` + `dock_to_board(board_rect, spawn_lane)`; `spawn_lane` = the one-cell strip above
  the board where tiles drop in (score keeps clear of it, opaque cards may cover it). A new board-adjacent HUD element implements both and joins that list.
- Card columns/rows report fixed reserved bands at the screen edges in `hud_rects()`, then are docked
  to the board edges (`dock_to_board`, both orientations; board rect excludes the camera margin) —
  reporting docked positions would feed back into the camera fit.
- Verify layouts with windowed screenshots (`--windowed --resolution 540x1170`, save
  `root.get_texture().get_image()` after ~90 frames).

## UI size (touch)

- `GameRoot.UI_SCALE` (1.25) → `Window.content_scale_factor`: one knob for all 2D UI; layout code
  works in the scaled canvas, so the board fit adapts on its own.
- `GameMenu` is deliberately large (`FONT_SIZE`, `ROW_HEIGHT`, `OPEN_BUTTON_SIZE`); its dropdown popup
  needs its own font size (popups don't inherit the panel theme).
- Portrait card rows share the width (`BattleView._fit_card`): full cards when they fit, else compact
  down to `CharacterCard.COMPACT_WIDTH`; check five-card rows at level 20 (right edge ≤ width).

## HUD and camera

- `GameRoot._free_screen_rect()` collects visible HUD rects; each full-screen view exposes
  `hud_rects()`. Each rect cuts the free area from the edge costing the smallest screen share.
  `_place_camera()` fits and centers the board in the free area (`h_offset`, `v_offset`; picking
  unaffected). `_refit_camera()` waits one frame for container layout.
- New HUD element: add its rect to `_free_screen_rect()` (or to its view's `hud_rects()`).
- `MoveAssist` (`view/hud/`): idle hint and Shuffle button; overlays the board, not counted as HUD.
- `RollingCounter` (`view/hud/`): animated number on a center-aligned `Label` (roll toward target,
  combo-scaled punch, re-target redirects the tween). Use it for every changing number (score, power).
