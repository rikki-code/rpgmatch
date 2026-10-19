---
name: match3-architecture
description: >
  Module map of the match-3 engine (core/view/game) and the main architecture
  rule (composition over if/else, core not scene-bound). Read before any edit
  in core/, view/, or game/. Use when working on this Godot match-3 project's
  core gameplay code.
---

## Modules

- `core/board/` — board graph (+ `MoveFinder`: every legal move with its value, `BoardShuffler`): `BoardGraph` (also carries game constants like `colors` (the board's random color subset, `random_color()`),
  `bomb_spawn_chance`, and transient turn state — `swapped_tiles`, the only object actually threaded
  into every hook), `GridCell`, `CellKind` (`NormalCellKind`/`PitCellKind`), generation
  (`BoardGenerator`, `WorldGenParams`), serialization (`BoardLayout`).
- `core/entities/` — everything that occupies a cell: `BoardEntity` → `Tile` (+ `TileBehavior` list,
  assembled by static factories on `Tile` — `make_normal`/`make_bomb`/`make_color_bomb`/
  `make_arrow_blaster`/`make_prism`, never by hand at the call site), future `Obstacle`, freeze
  wrapper, etc.
  `core/entities/behaviors/` — the `TileBehavior`s themselves (`ColorBehavior`,
  `SplashDamageBehavior`, and the detonable bonuses: `TriggerCore` — shared base `TileBehavior`
  (re-trigger guard + `on_damage`), subclassed by `BombCore`/`ArrowBlasterCore`/`PrismCore` (each its
  own blast shape via `_do_trigger`; `PrismCore` targets by current board-majority color, not
  radius/line); layered on top are reusable thin behaviors `ManualTriggerBehavior`/
  `MatchTriggerBehavior`/`SwapSplashTriggerBehavior`, each holding a ref to the shared `TriggerCore`,
  not a concrete `BombCore`/`ArrowBlasterCore`/`PrismCore` — a new bonus tile of the same kind reuses
  them directly instead of copying. Combining two bonuses via swap is also on `TriggerCore`:
  `can_combine_with_core(other) -> bool` (pure check) + `_do_combine_with(other, cell, board) ->
  Array[Effect]` (the recipe — not necessarily one tile on the swap cell; `PrismCore`'s recipe is
  asymmetric and hits several cells at once).
- `core/match/` — connected-group search (`MatchFinder`, `MatchGroup`). Two-tile compatibility is
  always checked **mutually** (`a.can_match_with(b) and b.can_match_with(a)`), both for finding runs
  and for merging adjacent runs in the flood-fill — a one-sided check falsely matches/merges tiles
  without shared match behavior (see `docs/architecture.md`).
- `core/effects/` — `Effect` (polymorphic chain) + `EffectResolver` (queue, reentrant — an effect can
  call `resolver.resolve(...)` from inside its own `execute()`). Destruction/gravity/spawn/
  damage/blast are all `Effect` subclasses. Damage is two tiers, two effects: `EffectSplashDamage`
  (soft → `on_splash_damage`) and `EffectBlastDamage` (hard, from a blast → `on_damage`) — don't mix
  them up when adding a new damage source.
- `core/swap/` — `SwapController`: validation + swap attempt + rollback.
- `core/actions/` — controllers for direct player actions that aren't a swap (`ShuffleController`,
  `DetonateController`:
  activates a tile via `TileBehavior.manual_trigger`, triggered by double-click — see
  `TileBehavior.is_manually_triggerable`; hooks are named generically, not per mechanic).
- `core/turns/` — `TurnPhase` + `TurnManager` (ordered phase list).
- `core/actors/` — `TurnActor` (base for enemies/environment), currently a stub.
- `core/scoring/` — `ScoreTracker`: self-subscribes to `EffectResolver.effect_applied`,
  awards `entity.score_value() * combo_factor()` for every tile removed
  (`EffectDestroyTile.removed_entity` or `EffectEntityRemoved` — both mean
  "a tile left the board", scored the same). Lives on `TurnContext` (not
  `BoardGraph`) since only phases/controllers need to call `begin_wave()`/
  `reset_combo()`, not `Effect.execute()`.
- `core/quests/` — `QuestDefinition` (Resource), `QuestProgress` (runtime),
  `QuestManager` (self-subscribes like `ScoreTracker`, matches destroyed
  entities via `BoardEntity.quest_kind_id()`), `QuestGenerator`/
  `RandomQuestGenerator` (infinite-mode random targets).
- `core/characters/` — battle: `Character`, `BattleContext`, controllers (`Human`/`AiController`),
  `UnitType`/`EncounterGenerator`, `CombatResolver`; `core/characters/actions/` — `BattleAction`
  subclasses (`AttackAction`/`DefendAction`), one file per action, never an enum + `if`. See
  `.claude/skills/match3-battle/SKILL.md`.
- `core/modes/` — `GameMode` (`InfiniteMode`/`BattleMode`): phase list + board params per mode;
  level is passed in, never stored. See `.claude/skills/match3-game-shell/SKILL.md`.
- `core/progression/` — `LevelCurve`: every per-level growth curve goes through it.
- `core/editor/` — `BoardEditController`: direct `BoardGraph` mutations for the in-game world editor
  (add/remove cell, place/erase tile), bypassing the turn/effect pipeline, gated by
  `ctx.awaiting_player_input`. See `.claude/skills/match3-world-editor/SKILL.md`.
- `view/` — top-down `Node3D` scene, renders `BoardGraph`, listens to `EffectResolver` signals for
  animation, converts mouse clicks/double-clicks into `SwapController`/`DetonateController` calls.
  **Decides nothing itself.** Mesh/material/marker geometry are `.tscn`/`.tres` under `view/packs/`,
  never assembled in code — see `TileView` (picks a scene by `Tile.visual_kind()`) and
  `tile_explosion.tscn` (self-contained VFX with its own `play()`). Pack layout, switching the active
  pack, `load()` instead of `preload()` for constant-built paths —
  `.claude/skills/match3-view-packs/SKILL.md`.
  `view/editor/` — world-editor UI/input (R-toggle, toolbar, grid overlay, placeable cell/tile
  catalogs) on top of the same `BoardView3D`/`InputController` — see
  `.claude/skills/match3-world-editor/SKILL.md`.
  `view/battle/` (character cards), `view/menu/` (pause menu), `view/hud/` (score, quests, move
  hint/shuffle) — UI built in code; reads state, emits picks/signals.
- `game/` — `game_root` wires everything (params → generator → graph → mode → turn manager → view);
  `game_session` holds the only state that survives a scene reload.
- Build/CI — `ci/`, `.github/workflows/export.yml`; see `.claude/skills/ci-export/SKILL.md`.

## Main rule

Core (`core/`) is plain GDScript classes (`RefCounted`/`Resource`), not `Node`, and knows nothing
about `.tscn`/scenes (see `visual_kind()` — a tag, not a resource ref). New mechanic = new file (new
`TileBehavior`/`Effect`/`CellKind`/`TurnActor`/`TurnPhase`/`BattleAction`/`CharacterController`), not
`if/elif` in existing code. Variants of an existing mode or unit are data, not subclasses. Detailed
recipe — `.claude/skills/match3-add-mechanic/SKILL.md`.

Full rationale — `docs/architecture.md`. Mechanics list and status — `docs/plan.md`.

## Comments

Keep them short. At most one `##`/`#` per method/field, only if it explains a non-obvious WHY (hidden
invariant, bug workaround, reason for a decision). Never explain what code does — names already do.
No multi-line paragraphs per function/constant.

## Verifying code

See `.claude/skills/godot-verify/SKILL.md` — headless check-only and where to find the runtime log if
the editor is already open.
