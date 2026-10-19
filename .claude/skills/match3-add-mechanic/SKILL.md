---
name: match3-add-mechanic
description: >
  "New mechanic → what file to create" recipe for the match-3 engine: bonus
  tiles, penalty tiles, obstacles, enemies, new cell types, new turn phases,
  new effect chains. Use when adding a new gameplay mechanic to this match-3
  project.
---

## Rule

Don't add `if/elif` on object type into an existing file. Instead create a new class implementing an
existing hook.

## "I want X → I make Y"

| Want to add | Create | Where |
|---|---|---|
| Bonus tile (bomb, disco ball, wildcard...) | new `TileBehavior` | `core/entities/behaviors/` |
| Penalty tile that blocks something (freeze) | new `BoardEntity` wrapper holding another `BoardEntity` | `core/entities/` |
| Turn-based penalty tile (changes color) | new `TileBehavior` implementing `on_turn_tick` | `core/entities/behaviors/` |
| Destructible obstacle (rock) | new `BoardEntity` with `on_damage` | `core/entities/` |
| New cell type (stub pit, impassable, portal) | new `CellKind` | `core/board/` |
| Chain reaction (blast, AoE damage, cascade) | new `Effect`, queues other `Effect`s | `core/effects/` |
| Enemy / environment agent acting in its own phase | new `TurnActor` with `take_turn(board) -> Array[Effect]` | `core/actors/` |
| New turn phase / different phase order | new `TurnPhase` + edit the mode's `build_phases()` list | `core/turns/phases/`, `core/modes/` |
| New game mode | configure an existing `GameMode` if phases match; subclass `GameMode` otherwise | `core/modes/` — see `.claude/skills/match3-game-shell/SKILL.md` |
| New battle action (heal, ability) | `BattleAction` subclass + entry in `BattleContext.actions` | `core/characters/actions/` — see `.claude/skills/match3-battle/SKILL.md` |
| New battle unit | one `UnitType.new(...)` in a catalog, cost calibrated by duels | `core/characters/unit_type.gd` |
| New character controller (network, scripted) | `CharacterController` subclass | `core/characters/` |
| Level-scaled value | `LevelCurve` call, never inline math | `core/progression/` |
| Special swap rule (e.g. allow non-adjacent swap for a special tile) | extend/replace `SwapController`, don't hardcode into `MatchFinder` | `core/swap/` |
| Direct player action besides swap (click-to-activate, shuffle) | new controller modeled on `DetonateController`/`ShuffleController` (`try_*` gated, `perform_*` for AI) + reuse `is_manually_triggerable`/`manual_trigger` (generic, not bomb-specific), not `on_damage`/`on_splash_damage` | `core/actions/` |
| Custom visual for a bonus/special tile | `TileBehavior.visual_kind()` returns a new tag + `.tscn`/`.tres` in `view/entity_views/` + entry in `TileView.SCENES_BY_VISUAL_KIND` | `core/entities/behaviors/` (tag), `view/entity_views/` (scene) |
| One-shot visual effect (explosion, flash, particles) | new `Effect` tag for `view` (e.g. `EffectBombBlast`) + self-contained `.tscn` with its own script (`play()`/cleanup inside) | `core/effects/` (tag), `view/effects/` (scene) |
| Make a new cell/tile placeable in the in-game editor | one `Entry` in `EditorCellCatalog`/`EditorTileCatalog`, no other editor code touched | `view/editor/` — see `.claude/skills/match3-world-editor/SKILL.md` |

## Existing hooks

- `TileBehavior`: `can_match_with(self, other)`, `on_matched(self, cell, board) -> Array[Effect]`,
  `on_turn_tick(self, cell, board) -> Array[Effect]`, `blocks_swap(self) -> bool`,
  `visual_kind(self) -> StringName` (semantic tag for `view`, not a scene ref — core knows nothing
  about `.tscn`).
  - Two independent damage tiers (don't confuse them — see below):
    `on_splash_damage(self, amount, cell, board) -> Array[Effect]` (soft, mostly ignored) and
    `on_damage(self, amount, cell, board) -> Array[Effect]` (hard, from a blast).
  - `is_manually_triggerable(self) -> bool` / `manual_trigger(self, cell, board) -> Array[Effect]` —
    named generically ("manual trigger"), not per mechanic (bomb etc.); a separate pair from
    `on_damage`/`on_splash_damage` so a direct player action isn't gated by whatever currently limits
    damage — see `SwapSplashTriggerBehavior`/`TriggerCore`.
- `BoardEntity`:
  - `can_fall() -> bool`.
  - `on_splash_damage(amount, cell, board) -> Array[Effect]` — **soft** damage, default no-op (an
    HP-less entity ignores chip damage). Delivered by `EffectSplashDamage`. Current source:
    `SplashDamageBehavior.on_matched` (destroyed normal tile sends 1 damage to its 4 neighbors).
  - `on_damage(amount, cell, board) -> Array[Effect]` — **hard** damage from a direct blast, default
    `[EffectDestroyTile.new(cell)]` (HP-less entity dies with zero override needed). Delivered by
    `EffectBlastDamage` (source: `EffectBombBlast`/`EffectArrowBlast`). Override only when the
    reaction is more than "just die" (see `TriggerCore.on_damage` — detonates itself instead).
- `CellKind`: `can_hold_tile() -> bool` (add more virtual hooks to the base class as new mechanics
  need extra intervention points).
- `Effect`: `execute(board) -> Array[Effect]`. Examples: `EffectDestroyTile`,
  `EffectSplashDamage`/`EffectBlastDamage` (the two damage tiers, above), `EffectGravityColumn`,
  `EffectSpawnTile`. An effect can synchronously call `resolver.resolve(...)` inside its own
  `execute()` (reentrant — `EffectResolver` has no instance state) to fully drain a sub-cascade before
  returning the next effect — see `EffectResolveMatchGroup`.
- `TurnPhase`: `enter(ctx)`, `execute(ctx)`, `exit(ctx)`.
- Don't hand-assemble a tile (`Tile.new()` + `.behaviors.append(...)`) in new code — add a static
  factory on `Tile` (modeled on `make_normal`/`make_bomb`/`make_arrow_blaster`) for a new "recipe" of
  existing behaviors.
- If several `TileBehavior`s on one tile need to agree on "who fired first" or share params (radius,
  direction) — give them a shared small object held by reference. For "detonate once, multiple
  triggers", use the existing base `TriggerCore` (`core/entities/behaviors/trigger_core.gd`): holds
  the re-trigger guard and implements `on_damage`; subclasses only override
  `_do_trigger(self_tile, cell, board)` with their own blast shape (see
  `BombCore`/`ArrowBlasterCore`/`PrismCore`). The thin `ManualTriggerBehavior`/`MatchTriggerBehavior`/
  `SwapSplashTriggerBehavior` are already generic and accept any `TriggerCore` — no need to rewrite
  them for a new detonable bonus, just a new `TriggerCore` subclass with its own blast shape.
  - Combining two bonus tiles via swap (see `SwapController`, `CombineEffectsBehavior`) also lives on
    `TriggerCore`: `can_combine_with_core(other: TriggerCore) -> bool` (pure check, no mutation,
    called from both sides before a decision) and `_do_combine_with(other, cell, board) ->
    Array[Effect]` (the recipe). Returns `Array[Effect]`, not a ready `Tile` — the recipe doesn't have
    to collapse to "one new tile on the swap cell" (see `PrismCore`: hits several board cells at
    once instead of merging into one tile). For the simple "place one merged tile and detonate" case
    there's the static helper `TriggerCore._place_and_trigger(tile, cell, board)` — queues
    `EffectPlaceTile` + `EffectTriggerTile` as two separate resolver steps (don't mutate the cell and
    call `trigger()` inline — `view` won't get to build the tile's node before it detonates).
    `TriggerCore.spawn_similar_tile() -> Tile` — another hook, "give me a fresh tile of my own kind",
    needed if your recipe (like `PrismCore`) spawns a copy of the **partner** without knowing its
    concrete class.

## If no hook fits

If existing hooks don't cover a new mechanic, don't force it through if/else — add a new virtual
method to the relevant base class (`TileBehavior`/`CellKind`/`Effect`/`TurnPhase`) with a no-op
default. If it's unclear which class or how — ask the user, don't decide the architecture solo.
