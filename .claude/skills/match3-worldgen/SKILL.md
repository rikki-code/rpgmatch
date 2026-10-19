---
name: match3-worldgen
description: >
  Procedural board generation params (WorldGenParams) and the BoardGenerator
  flow in the match-3 engine: how to add a new generation param. Use when
  working on procedural level/world generation in this match-3 project.
---

## WorldGenParams (`core/board/world_gen_params.gd`)

A Resource with generation fields: `width`, `height`, `color_count`, `pit_count` (or density),
`seed`, `difficulty`, `allow_enemies`, `allow_penalties`. The `allow_*` toggles exist ahead of time —
the mechanic itself (enemies/penalties) may not be built yet, but the generator is already ready to
respect/disable it once it lands.

## BoardGenerator (`core/board/board_generator.gd`)

1. Builds a rectangular `BoardGraph` of the requested size (cells + 4-neighbors).
2. Randomly assigns `PitCellKind` to a share of cells per `pit_count`/density.
3. Picks a random subset of `color_count` colors out of `BoardGraph.MAX_COLORS` into
   `BoardGraph.colors` (different every generation), then spawns `Tile`s from it on non-pit cells,
   checking the layout doesn't create a
   starting match ≥3 (re-picks color on conflict, not a post-hoc cleanup).
4. Where needed (once enemies/obstacles/penalty tiles exist) — places them here too, driven by
   `allow_enemies`/`allow_penalties`/`difficulty`, without touching steps 1–3.

## Adding a new generation param

1. Add an `@export` field to `WorldGenParams`.
2. Use it in `BoardGenerator` at the matching step (don't mix it into unrelated steps — the generator
   should stay a sequence of independent steps, not one large branching function).
3. Document the field in `docs/plan.md` ("Procedural generation" section).

Live example of a param that affects ongoing gameplay config rather than generation itself:
`bomb_spawn_chance`/`color_bomb_spawn_chance` — `@export` fields on `WorldGenParams`, copied into
`BoardGraph.bomb_spawn_chance`/`color_bomb_spawn_chance` in `BoardGenerator.generate()`, then read during play (`EffectSpawnTile` — chance to drop a bomb/color bomb instead
of a normal tile on gravity respawn, checked in sequence). These fields don't touch initial placement
(`_spawn_tiles`).

## Per-mode params

`GameMode.board_params(base, level)` derives the actual params from the menu settings (`base`).
`BattleMode` starts at 6×6, 3 colors, no holes and grows each with `LevelCurve.stepped`, capped by
`base`. Infinite mode returns `base` unchanged.

## Hand-built levels

`BoardLayout` (Resource, `core/board/board_layout.gd`) — an alternate input: a serialized layout of
cells/pits/fixed tiles, saved via `ResourceSaver` as `.tres`. `BoardGenerator` and `BoardLayout` are
two independent ways to get a `BoardGraph` — both must produce the same structure so the rest of the
code doesn't care where the board came from.
