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
- The start screen lists `ModeCatalog.all()`: one `ModeDefinition` each (`core/modes/definitions/`):
  title, `settings_schema()` (`SettingSpec`: int knob with range/default/suffix),
  `create_mode(settings)`, `world_params(settings)`, `start_level(settings)`, optional `presets()`
  (`SettingPreset`, difficulty bundles that may carry hidden keys like bonus chances; the `preset`
  setting is an index, `presets().size()` = Custom). `ModeSetupForm` builds the form from the schema
  (preset row, plain settings, `SettingSpec.as_advanced()` ones behind an Advanced toggle), so a new mode = one definition file + one `ModeCatalog` line, no UI edits.
- New `GameMode` subclass only when the phase list differs; otherwise configure an existing mode
  (PvP = `BattleMode` with N humans per side and budget 0).

## State and scenes

- `GameSession.launch: RunConfig` (mode id + settings + progression `level`) survives scene reload; it
  is the only copy, core receives values as parameters. Victory does `launch.level += 1`.
- Two top-level scenes, `SceneRouter.to_menu()` / `to_game(config)`: `game/menu_root.tscn` (main scene,
  `MenuRoot` → `ModeSelect`) and `game/game_root.tscn`. Running game_root directly falls back to
  default Battle settings.

## Profile and stats

- `GameSession.profile()` (`ProfileData`, loaded by `SaveStore` from `user://profile.json`): per-mode
  `ModeStats` and the last settings of each mode. `StatsRecorder` (made in `GameRoot._ready`) counts
  tiles, best score, wins/losses, best level; `GameRoot._save_stats()` writes when dirty (turn-cycle
  end, battle end, `_exit_tree`). `MenuRoot._on_start` remembers the settings and counts `runs`.
- A mode shows stats through `ModeDefinition.stat_specs()`; keys live in `ModeStats`. Battle's start
  level range comes from `settings_schema(stats)` (reached level), saved settings are re-clamped by
  `resolve_settings`. New stat = key const in `ModeStats` + a line in `StatsRecorder` + a `StatSpec`.
- Only `SaveStore` touches files; web `user://` is IndexedDB, so save at checkpoints, not at close.

## Continue (run saves)

- Slot per mode, `user://run_<mode>.json` (`RunSave` = config + `GameSnapshot`), written by
  `GameRoot._save_run` at every turn-cycle end, deleted when a battle ends. Details and the restore
  sequence: `.claude/docs/architecture.md`, "Continue".
- New saved state = `to_dict`/`restore` on its owner plus a key in `GameSnapshot.capture`; a new class
  family needs a codec line (`Tile.from_recipe`, `CellKindCodec`, `ControllerCodec`, `EntityCodec`), not a
  generic object serializer. Changing the format = bump `RunSave.VERSION` and migrate in `from_dict`.
- `BattleContext.is_versus()` (humans on both sides, i.e. PvP) makes the end screen name the winner and
  offer a Rematch on the same level instead of Next battle.

## Switching and restart

- `GameRoot.switch_mode(mode)` (debug-build editor toolbar only): same board, new `TurnManager`. When the
  board is busy, it calls `turn_manager.request_hold()` and applies on `held`; `_switch_definition`
  also replaces `GameSession.launch`.
- Restart, next battle: `get_tree().reload_current_scene()`; unpause first.
- Cross-frame waits must be view-owned tweens (`create_tween().tween_interval`), never
  `SceneTree.create_timer` — timers survive reload and resume coroutines on freed objects.

## Menu

- `GameMenu` (`view/menu/`, built in code): ☰ / Esc, `get_tree().paused`, `PROCESS_MODE_ALWAYS`.
  Resume / Settings (tile + board pack, applied on pick, no new board) / Restart / Main menu; emits
  `pack_selected`, `restart_requested`, `exit_requested`. No mode switching here; the world editor is
  the R key, debug builds only (its toolbar keeps a mode dropdown).
- `ModeSelect` + `MenuKit` (`view/menu/`): start screen, one plain button per mode. Start/Back are pinned under the scrolling form.

## Orientation (mobile)

- `UiScale.fit()` (`view/ui_scale.gd`, used by both top-level scenes): portrait window → base size turned portrait (1080×1920); landscape keeps
  the project size. UI is never shrunk to a 1920-wide canvas on phones.
- Views branch on their own `size.y > size.x` (see `BattleView._apply_layout`): landscape = side
  columns, portrait = rows; compact cards (`CharacterCard.set_compact`).
- Docked HUD (`GameRoot._docked_hud()`: `ScoreHud`, `QuestHud`, `BattleView`) implements
  `hud_rects()` + `dock_to_board(board_rect, spawn_lane)`; `spawn_lane` = the one-cell strip above
  the board where tiles drop in (score keeps clear of it, opaque cards may cover it). A new board-adjacent HUD element implements both and joins that list.
- Card columns/rows report fixed reserved bands at the screen edges in `hud_rects()`, then are docked
  to the board edges (`dock_to_board`, both orientations; board rect excludes the camera margin) —
  reporting docked positions would feed back into the camera fit.
- Verify layouts with windowed screenshots (`--windowed --resolution 786x1704` = iPhone 15's 393×852 points on a 2x Retina screen; save
  `root.get_texture().get_image()` after ~90 frames).

## UI size (touch)

- `UiScale.FACTOR` (1.25) → `Window.content_scale_factor`: one knob for all 2D UI; layout code
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
