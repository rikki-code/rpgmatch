---
name: match3-view-packs
description: >
  How visual packs (`view/packs/`) are structured and how to add/swap tile,
  cell, special-tile, or background packs. Use when adding or editing
  tile/cell/effect visuals, materials, or when asked to swap a skin/theme.
---

## Structure

`view/packs/<category>_pack/<pack_name>/` — only `.tscn`/`.tres` (visuals), no `.gd` logic (except
self-contained pooled VFX scripts (`Vfx`, see `view/vfx/`) like `tile_explosion.gd` that ship with their own
scene).

- `tiles_pack/` — normal colored tiles. Packs: `crystal_pack/` and `six_seven_pack/` (flat stickers
  with the digits 6 and 7 only, one bundled OFL font per sticker in `fonts/` (licenses alongside),
  `Label3D` on a disc/box tinted from the palette; some stickers stagger 6 and 7 like the meme's
  see-saw gesture). A pack holds
  `tile_0.tscn`…`tile_5.tscn` (root child `Mesh`: the tinted body, `TileView` recolors it),
  `tile_material.tres`, `tile_colors.tres`, and `match_lightning.tscn` + its material (the script
  `MatchLightning` lives in `view/vfx/`).
- `board_pack/` — what the board stands on. Packs: `dungeon_pack/` (stone slabs, gold-trimmed stone
  frame, corner braziers) and `earth_pack/` (grass slabs, log fence, lanterns, `meadow_floor.gdshader` floor). A pack holds
  `cell_ground.tscn`, `cell_ground_alt.tscn` (the second checkerboard shade), `cell_pit.tscn`,
  `board_floor.tscn`, and `board_frame.tscn` whose root script extends `BoardDecor` and sizes the
  frame in `fit(width, height)`. `CellLayer` instances them.
- `special_tiles_pack/` — bombs, arrow blasters, and future bonus/penalty tiles. Currently:
  `standard_pack/` (`tile_bomb.tscn` + materials, `tile_arrow_blaster.tscn` + materials — one asset
  for both axes, `TileView` rotates the node 90° for `Axis.COLUMN`; `tile_explosion.*` — explosion
  shared by bomb and arrow blaster; `arrow_blast_bolt.*` — "energy bolt" flying along the cleared
  line).
- `background_pack/` — environment/background. Currently: `standard_pack/` (`board_environment.tres`).
- `battle_fx_pack/` — battle action VFX (2D, UI layer). Currently: `standard_pack/`:
  `charge_aura.tscn` (soft rising flame aura, motes, rare edge sparks), `action_bolt.tscn` (orb, arcs,
  sparks, trail), `action_burst.tscn` (flash, shockwave, orb splash, motes), `action_colors.tres` (`ActionColorPalette`, keyed by
  `BattleAction.visual_kind()`), `energy_*.gdshader` + `energy_noise.gdshaderinc`. Self-contained
  scripts ship with their scenes (`charge_aura.gd`, `action_bolt.gd`, `action_burst.gd`,
  `lightning_arcs.gd`, `edge_arcs.gd`); `BattleFx`/`CharacterCard` only instance and call them.
  Scene interface: aura `set_energy_color/set_intensity/get_intensity/fit`, bolt `launch` + `landed`,
  burst `play`.

Tile files are named **without** a concrete-visual tie (`tile_0.tscn`, not `tile_crystal_0.tscn`) —
the concrete shape (crystal, cupcake, whatever) is a pack's job; the filename should work in any pack
of the same category.

## Switching the active pack

`PackCatalog` (`view/pack_catalog.gd`) lists the selectable packs per category (tiles, board) and
saves the choice in `user://packs.cfg`. The menu's Settings page has a dropdown per category; Apply
calls `GameRoot._apply_packs` (save, `PackPaths.refresh()`, `TileView/CellLayer/VfxPool.load_packs()`)
and reloads the scene. A new pack = a folder with the same file layout + one entry in
`PackCatalog.OPTIONS`. `PackPaths` holds the active base path of every category (the fixed ones are
consts). `PackCatalog` must not reference the consumers: `PackPaths` reads it during static init and
a back-reference makes a static-init cycle.

The static scene caches are filled once per process, so switching is only safe through that
reload path (already-spawned nodes are not rebuilt).

`view/editor/` (in-game world editor, see `.claude/skills/match3-world-editor/SKILL.md`) is not a pack
and isn't swappable, but its toolbar renders dropdown previews by instancing the same pack scenes via
`TileView.build_node()`/`CellLayer.SCENES_BY_VISUAL_KIND` inside an offscreen `SubViewport`,
rather than a separate icon set.

## Why load(), not preload()

`.tscn`/`.tres` are static data with no expressions, so `preload("res://...")` needs a **literal**
path — a constant can't be substituted in. So pack scenes/materials are loaded via
`load(PackPaths.X + "file.tscn")` inside `static func _static_init()` (Godot 4.3+ static class
constructor) into a `static var`, not `const ... := preload(...)`. See `TileView`/`BoardView3D` — same
pattern everywhere.

Same reason **geometry numbers inside `.tscn`** (`radius`, `height`, `size`…) can't reference a
GDScript constant either — they're plain literals hand-picked to match
`GeometryConstants.DEFAULT_TILE_RADIUS`/`CELL_SIZE` (see `view/geometry_constants.gd`), not automated.

- `ui_pack/` — UI assets. Currently: `standard_pack/`: `ui_font.woff2` (Inter, OFL — license file
  alongside; also the project `gui/theme/custom_font`, update it when swapping), `menu_icon.svg`,
  `rpg_theme.tres` (project `gui/theme/custom`: dark panels, bronze borders, gold hover — styles
  every default Button/Panel/OptionButton/ProgressBar/popup).

## Rules for new visuals

- Visual nodes, materials, particles, shaders → a pack scene/resource, never assembled in `.gd`.
- Per-instance shader params: `resource_local_to_scene = true` on the `ShaderMaterial`.
- Particle tint: neutral (white) `color_ramp` in the scene, `CPUParticles2D.color` set at runtime.
- UI symbols: web builds have no system font fallback — any glyph must exist in `ui_font.woff2`
  (check with `FontFile.has_char`), otherwise use an icon from the UI pack.
- New imported asset (font, svg): run `godot --headless --path . --import` before headless checks.
- 2D shaders: see the precision and warm-up pitfalls in `.claude/skills/match3-battle/SKILL.md`.

## Color palette is also part of a pack

`view/tile_color_palette.gd` (`TileColorPalette`, a `Resource` with `@export var colors: Array[Color]`)
isn't hardcoded in `TileView` — it lives as `tile_colors.tres` inside the pack
(`tile_colors.tres` of the active tiles pack), loaded by the same `load_packs()`.

## New global class → rescan the cache

Adding a new `.gd` with `class_name` (like `PackPaths`, `TileColorPalette`, `GeometryConstants`) won't
be seen by headless `--check-only` until `.godot/global_script_class_cache.cfg` is rebuilt. See
`.claude/skills/godot-verify/SKILL.md`.
