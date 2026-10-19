---
name: match3-world-editor
description: >
  In-game world editor (R key): core/editor + view/editor architecture,
  placeable cell/tile catalogs, why mutations bypass the turn/effect
  pipeline, and how to add a new cell/tile type to the dropdowns without
  touching the rest of the editor. Use when touching the world editor (add/
  remove cell, place/erase tile in the running game) in this match-3 project.
---

## What it is

An editing mode for the currently running board, inline in the game — not a separate scene. Entry
points: the `R` key and the menu's Mode list ("Editor (R)"), both calling `EditorModeController.toggle()`.
If the board is busy, `toggle()` requests `TurnManager.request_hold()` and opens on `held`; a second
press while pending cancels.

While active: the normal `InputController` (swap/detonate) is muted (`set_editor_active`), a
translucent grid overlay shows over the board (`EditorGridOverlay`), and a toolbar sits at the bottom
of the screen (`EditorToolbar`).

## Modules

- `core/editor/board_edit_controller.gd` (`BoardEditController`, `RefCounted`) — the only place that
  actually mutates `BoardGraph` from the editor: `set_cell_kind`/`remove_cell`/`place_tile`/
  `clear_tile`. Mutates directly (`cell.occupant = ...`), bypassing `Effect`/`Resolver` — same as
  `BoardGenerator`/`BoardLayout.build_graph()` — an editor edit isn't a game action, nothing to
  animate/resolve. **Every method refuses if `not ctx.awaiting_player_input`** — deliberately
  duplicating the mode-entry check in `EditorModeController.toggle()`: the guarantee "can't mutate the
  board mid-cascade" lives in the mutator itself, not only in the calling UI code.
- `view/editor/editor_mode_controller.gd` (`Node3D`) — R-toggle, current tool
  (`ToolKind.SET_CELL_KIND` / `REMOVE_CELL` / `PLACE_TILE`, mutually exclusive), converts clicks into
  `BoardEditController` calls. While open it sets `ctx.awaiting_player_input = true` (the edit gate)
  and restores the previous value on exit. Exit: `link_grid_neighbors()` + `cells.sync()` +
  `refresh(null, true)`, then `PhasePhysicsResolve.settle(ctx)` with input locked, `reset_combo()`
  (edit matches never feed the turn), restore input state, emit `settled`, and `release()` the held
  manager if it is still current. Editing never ends or skips a turn.
- `view/editor/editor_cell_catalog.gd` (`EditorCellCatalog`) — registry of placeable `CellKind`s:
  `{id, display_name, factory: Callable -> CellKind}`.
- `view/editor/editor_tile_catalog.gd` (`EditorTileCatalog`) — registry of placeable tiles:
  `{id, category (NORMAL/SPECIAL), display_name, factory: Callable -> Tile}`. First entry is
  `"erase"` with an **invalid** `Callable` (`Callable()`) — a special "remove tile from cell" marker,
  checked via `factory.is_valid()`, not a separate enum/flag.
- `view/editor/editor_grid_overlay.gd` + `editor_grid_cell.tscn` — a translucent marker at every board
  coordinate (including empty ones — otherwise there's nowhere to click to add a cell), visible only
  while the editor is active.
- `view/editor/editor_toolbar.gd` + `.tscn` — a `Control` at the bottom of the screen: cell-type
  dropdown, Remove Cell button, two tile dropdowns (normal/special), Mode dropdown, Battle level spin
  box (`show_state()` syncs both on every open; a level change rebuilds the battle on the current
  board via `GameRoot._set_battle_level`). Visual is `.tscn`
  (Control/Button/OptionButton tree), script holds only logic (populating dropdowns, signals) — same
  split as `view/packs/`, though `view/editor/` itself isn't a pack and isn't swappable.

## Extending: a new cell/tile in the dropdown

Nothing in `EditorToolbar`/`EditorModeController` needs touching — this is the "I want X → I do Y"
table for the editor itself:

| Want to add | Create |
|---|---|
| New cell type in the dropdown ("sand" cover etc.) | one `EditorCellCatalog.Entry` in `EditorCellCatalog.build()` — first the `CellKind` itself (see `.claude/skills/match3-add-mechanic/SKILL.md`) |
| New placeable tile in the dropdown | one `EditorTileCatalog.Entry` in `EditorTileCatalog.build()`, `category` picks which of the two dropdowns it lands in |
| New tool (not cell/tile) | new `ToolKind` + branch in `EditorModeController._handle_click` + a toolbar element — see `_set_active_tool` in `editor_toolbar.gd` for highlighting the active tool |

## How the editor touches adjacent modules

- `BoardGraph.link_grid_neighbors()` (`core/board/board_graph.gd`) now **unconditionally** overwrites
  `cell.neighbors[dir]` (even to `null`), not only when a neighbor exists — otherwise `remove_cell()`
  would leave a dangling ref to an already-removed `GridCell` on its former neighbors.
  `BoardGraph.remove_cell(pos)` is a full cell removal (a hole in the graph, like a board edge — not
  `PitCellKind`, see `.claude/skills/match3-board-model/SKILL.md`), taking its occupant with it.
- `CellLayer.sync()` — diffs `_nodes`/`_visual_kinds` by position against the current
  `board.all_cells()`: builds a node for a new cell, removes one for a vanished cell, **rebuilds a
  node in place** if an existing cell's `kind.visual_kind()` changed (the editor can repaint a cell to
  a different kind without deleting/recreating the `GridCell`) — normal gameplay
  (`_build_cells()` once in `setup()`) never hits this branch.
- `BoardView3D.refresh(effect, instant)` — new `instant` param: snap with no tween (spawn/move/
  destroy). Normal gameplay (`ctx.resolver.effect_applied` → `refresh(effect)`) is always animated;
  the editor is the only caller passing `instant=true` (placing/removing a tile is authoring, not a
  game event — shouldn't look like "tile dropped from the sky").
- `InputController._editor_active` — a gate set via `set_editor_active()` from
  `EditorModeController.mode_changed`, so normal swipe-swap doesn't intercept clicks over the editor.

## Pitfalls already hit

- **Dropdown icons** render as real 3D scenes via an offscreen `SubViewport` (reuses
  `TileView.build_node()`/`CellLayer.SCENES_BY_VISUAL_KIND`, not a separate icon set) — but the
  `SubViewport` must live **outside** the node that `set_panel_visible()` hides (a `Panel` in the
  toolbar, not the scene root): hiding an ancestor stops the `SubViewport` from rendering, and
  `get_texture().get_image()` then silently returns something no texture can be built from.
- Camera/light inside such a `SubViewport` should be set via `position`/`rotation_degrees`, not a
  hand-written `Transform3D` — one basis mistake gives "no errors, but the icon is blank" (camera
  pointed away from the object), with nothing in the log.
- Hand-editing a `.tscn` as text: `%UniqueName` resolution can fail
  (`Can't use get_node() with absolute paths from outside the active scene tree`) on a scene not built
  through the Godot editor. Plain `$NodePath` is more reliable and matches the rest of the project
  (nowhere else uses `%`).
- `OptionButton.item_selected` only fires on an index **change** — clicking an item that's already
  visually selected (even if that dropdown isn't the active tool right now) doesn't signal. Use
  `option.get_popup().id_pressed` (fires on every item click) and explicitly set `id == index` on
  `add_item`/`add_icon_item`.
- Don't do radio-selection across dropdowns via `option.select(-1)` on the inactive ones — that erases
  their displayed text (an `OptionButton`'s text is its selected item's label). Highlight the active
  one via `modulate` instead (`_set_active_tool` in `editor_toolbar.gd`), leaving others' selection
  alone.

## Verifying code

See `.claude/skills/godot-verify/SKILL.md`. Also: a new global `class_name` in `view/editor/`/
`core/editor/` needs a `.godot/global_script_class_cache.cfg` rebuild, same as any other pack (see
"New global class" in `.claude/skills/match3-view-packs/SKILL.md`).
