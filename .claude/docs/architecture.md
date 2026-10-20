# Match-3 engine architecture

Records core architectural decisions. Read at the start of any session before touching `core/`,
`view/`, or `game/`.

## Goals

- `core/` — plain GDScript classes (`RefCounted`/`Resource`), **not scene-bound**. Lets logic be
  tested without opening the editor and reused across projects.
- `view/` — thin layer over core: builds the top-down 3D scene from `BoardGraph` state, turns player
  input into core calls. Decides nothing itself — only displays and delegates.
- Visuals (mesh/material/marker geometry) live as `.tscn`/`.tres` in
  `view/packs/<category>_pack/<pack>/`, never `MeshInstance3D.new()`/`StandardMaterial3D.new()` in
  code — art is edited in the Godot editor, not GDScript. An `EntityView` script only instances the
  scene and sets the one thing `.tscn` can't know ahead of time (e.g. a tile's color) — see
  `TileView`, `tile_explosion.tscn` (self-contained VFX with its own `play()`). Active pack selection
  lives in `view/pack_paths.gd` (`PackPaths`) — see `.claude/skills/match3-view-packs/SKILL.md`.
- New mechanic = **new file**, not an `if/elif` branch in an existing one. Main tool: polymorphism +
  composition (see `.claude/skills/match3-add-mechanic/SKILL.md`).

## Board model

- `BoardGraph` — a graph of cells, not a 2D array. Each `GridCell` holds explicit neighbor refs per
  direction (`grid_direction.gd`). Default generation builds a rectangular grid, but links can be
  rewired later (portals, segment rotation, conveyors) without touching algorithms that only walk
  `neighbors`.
- `CellKind` — polymorphic cell type, not an enum with checks. Base class defines virtual hooks
  (e.g. `can_hold_tile`). `NormalCellKind` = ordinary cell. `PitCellKind` (pit) is just
  `can_hold_tile() -> false` — it splits a column into segments exactly like a board edge, no extra
  special-casing (see `match3-board-model` skill). Gravity calls cell hooks, never `if kind == PIT`.
- `BoardEntity` — base for anything that can occupy a cell (tile, obstacle/rock, future stuff).

## Tiles and behaviors

- `Tile extends BoardEntity` doesn't grow via subclassing. A tile holds a list of `TileBehavior`
  (composition). Hooks: `can_match_with`, `on_matched`, `on_turn_tick`, `on_splash_damage`,
  `on_damage`, `blocks_swap`, `is_manually_triggerable`, `manual_trigger`, `visual_kind`.
- Tiles aren't built via `Tile.new()` + a manual behavior list at the call site — static factories on
  `Tile` (`make_normal`, `make_bomb`, `make_color_bomb`, `make_arrow_blaster`) fix "what a tile is
  made of" in one place. New tile kind = new factory + new/reused `TileBehavior` set, not a new
  `Tile` subclass.
- Implemented `TileBehavior`s: `ColorBehavior` (color match), `SplashDamageBehavior` (below), and
  detonable bonuses built around a shared `TriggerCore`: `BombCore`, `ArrowBlasterCore` (below).
  Remaining bonus/penalty tiles are future `TileBehavior`s — see `docs/plan.md`.
- `can_match_with` must be checked **mutually** by `MatchFinder`
  (`a.can_match_with(b) and b.can_match_with(a)`), never one-sided. A one-sided check used to produce
  false matches: a tile without `ColorBehavior` (e.g. a bomb, unset default `color`) got counted as
  "same color" by any neighbor sharing that raw numeric `color`, because `ColorBehavior.can_match_with`
  compared bare ints without checking whether the other side even supports color comparison.
- Frozen tile will be a separate wrapper `BoardEntity` (holds an arbitrary inner `BoardEntity` — tile,
  bomb, etc.), not a flag on `Tile` — keeps "can't move, HP-gated unfreeze" out of the base tile class.
- `visual_kind() -> StringName` — a semantic tag for `view`, not a scene reference (core knows nothing
  about `.tscn`). Don't reuse a gameplay hook (e.g. `is_manually_triggerable`) as a stand-in for "how
  this should look" — they're independent and can diverge.
- `is_manually_triggerable`/`manual_trigger` are named **generically**, not per mechanic ("detonate"
  etc.) — any future click-to-activate tile reuses these same hooks instead of inventing its own pair.

## Two damage tiers: splash vs blast

Damage is deliberately two concepts with different hooks, defaults, and `Effect` delivery — so a soft
"sneeze" from a neighboring match doesn't chain-destroy the whole board, while a direct blast hit
reliably kills:

- `BoardEntity.on_splash_damage(amount, cell, board) -> Array[Effect]` — **soft** damage, default
  no-op (an entity with no HP concept just ignores it). Delivered via `EffectSplashDamage`
  (`cell.occupant.on_splash_damage(...)`). Sole current source: `SplashDamageBehavior.on_matched` —
  a destroyed normal tile sends 1 damage to its 4 orthogonal neighbors. Mostly a no-op by itself
  (normal tiles ignore it) — exists so a neighboring bomb can react, without special-casing "what if
  it was a bomb" in the normal tile.
- `BoardEntity.on_damage(amount, cell, board) -> Array[Effect]` — **blast** damage, default
  `[EffectDestroyTile.new(cell)]` (an HP-less entity dies from a direct blast hit with zero override
  needed). Delivered via `EffectBlastDamage`, sent by `EffectBombBlast` to every cell in radius. A
  normal tile caught in someone else's blast dies via this default without overriding anything; a
  bomb overrides `on_damage` to detonate itself instead of just dying — so bomb-chains-bomb reactions
  are visible right in its own code, not smeared across generic `on_matched`/`EffectDestroyTile`.

## TriggerCore — shared detonation mechanism for bonus tiles

- `TriggerCore` (`core/entities/behaviors/trigger_core.gd`) — base `TileBehavior` all detonable
  bonuses grow from. Holds an `_exploded` guard (re-trigger = no-op) and implements `on_damage`: a
  direct blast hit **always** unconditionally detonates such a tile in response — no variant should
  ever opt out. Subclasses only override `_do_trigger(self_tile, cell, board) -> Array[Effect]` with
  their own blast shape; the guard/`on_damage` never needs copying.
- Around a given `TriggerCore` subclass sit thin `TileBehavior`s, each holding a ref to it (so they
  agree on blast params and share one `_exploded` guard — only one actually fires). Already
  **generic**, not bomb-specific, accept any `TriggerCore`:
  - `ManualTriggerBehavior` — `is_manually_triggerable`/`manual_trigger` (double-click,
    `DetonateController`).
  - `MatchTriggerBehavior` — `on_matched` (detonate as a reward for a color match; needs
    `ColorBehavior` on the same tile, otherwise it never enters a match group).
  - `SwapSplashTriggerBehavior` — `on_splash_damage`, but **only fires if the tile itself was one of
    the two swapped pieces** that created this match (`BoardGraph.swapped_tiles`; an unrelated
    neighboring match doesn't touch it).
- `BombCore extends TriggerCore` — holds `shape`/`radius` (a class field, not a constant — a stronger
  bomb is just a bigger radius in `_init`, no subclass needed). `_do_trigger`: Manhattan diamond or
  square (`BoardGraph.cells_within_manhattan_radius`/`cells_within_square_radius`) →
  `EffectBombBlast`.
  `Tile.make_bomb(radius)`: `[BombCore, ManualTriggerBehavior, SwapSplashTriggerBehavior]`, no
  `ColorBehavior` — black (`visual_color`), matches with nothing.
  `Tile.make_color_bomb(color, radius)`: `[ColorBehavior, BombCore, MatchTriggerBehavior,
  SwapSplashTriggerBehavior]`, no manual detonation — meant as a color-match reward, not a click-pop.
- `ArrowBlasterCore extends TriggerCore` — holds `axis` (`ROW`/`COLUMN`: which axis it clears) and
  `extra_lines` (extra parallel rows/columns cleared symmetrically, default 0). `_do_trigger`: whole
  row/column via `BoardGraph.cells_within_row_band`/`cells_within_column_band` → `EffectArrowBlast`.
  `Tile.make_arrow_blaster(axis, extra_lines)`: `[ArrowBlasterCore, ManualTriggerBehavior,
  SwapSplashTriggerBehavior]` — same trigger set as `make_bomb`, no color variant. Axis is chosen
  **opposite** to the match axis that spawned the tile (vertical match → horizontal clear, and vice
  versa) — see `EffectResolveMatchGroup._blast_axis_for`. `Axis.BOTH` (both axes at once) is only
  reachable by combining two arrow blasters (see combining below), never spawns from a match — its
  visual isn't a separate scene, just `tile_arrow_blaster.tscn` layered on itself as a second rotated
  instance (see `TileView.build_node`, tag `arrow_blaster_both`).
- `PrismCore extends TriggerCore` — the strongest bonus, no fixed radius/line: target is computed
  **live** from board state — whichever color is currently most common among normal tiles
  (`ColorBehavior`, `tile.color >= 0`) — and hits every cell of that color at once
  (`_dominant_color`/`_cells_with_color`) → `EffectPrismBlast` (view tag — colored bolt shot at each
  target, below). `Tile.make_prism()`: `[PrismCore, ManualTriggerBehavior, SwapSplashTriggerBehavior,
  CombineEffectsBehavior]`, no `ColorBehavior` — matches with nothing, like a normal bomb/arrow.

## Combining bonus tiles

- `CombineEffectsBehavior` — thin `TileBehavior` (present on every bonus), holds a ref to its
  `TriggerCore` and delegates both halves of the contract to it:
  `core.can_combine_with_core(other_core) -> bool` (pure check, no mutation — called from both sides
  of a swap before anything is decided, see `SwapController`) and
  `core._do_combine_with(other_core, cell, board) -> Array[Effect]` (the actual recipe, only called
  once a combine is confirmed). Named `*_core`, not bare `can_combine_with`/`_do_combine_with`,
  because `TileBehavior.can_combine_with(self_tile, other_tile)` already exists with a different
  signature (`Tile`, not `TriggerCore`) and can't be overridden with a different one.
- `_do_combine_with` returns `Array[Effect]`, not a ready `Tile` — the recipe isn't required to
  collapse to "one new tile on the swap cell" (see `PrismCore` below). For the simple case
  (Bomb+Bomb, Bomb+Arrow, Arrow+Arrow) there's a shared static helper
  `TriggerCore._place_and_trigger(tile, cell, board)` — queues `EffectPlaceTile` (tile appears as its
  own resolver step, so `view` actually builds its node) then `EffectTriggerTile` (detonates it next
  step), instead of mutating the cell and calling `trigger()` inline — otherwise `effect_applied` for
  the intermediate "tile appeared" state never reaches `view`, and the combined tile explodes without
  ever appearing on screen for a single resolver step.
- `TriggerCore.spawn_similar_tile() -> Tile` — virtual hook "give me a fresh tile of my own kind"
  (`BombCore` → `Tile.make_bomb(radius)`, `ArrowBlasterCore` → `Tile.make_arrow_blaster(axis,
  extra_lines)`, `PrismCore` → `Tile.make_prism()`), default `null`. Exists so `PrismCore` can spawn a
  copy of its **combine partner** without knowing its concrete class.
- `PrismCore` combining is an asymmetric recipe, not "merge into one stronger tile on the swap cell"
  like Bomb/Arrow:
  - Prism + Prism: skips color targeting entirely, hits **every** occupied board cell
    (`EffectPrismBlast` with `_all_occupied_cells`, no color — `color = -1`, `view` uses a neutral
    tint).
  - Prism + anything else: finds the current majority color (`_cells_with_color`/`_dominant_color`)
    and on **each** such cell spawns a fresh tile of the partner's kind
    (`partner_core.spawn_similar_tile()`) and detonates it on the spot
    (`combine_partner_into_majority`) — a color-driven chain, not one tile on the swap cell.
    `BombCore`/`ArrowBlasterCore` carry a pairing branch `if other is PrismCore: return
    PrismCore.combine_partner_into_majority(self, board)`, so the recipe fires the same regardless of
    which of the two tiles the player dragged onto the other (the combo dispatcher always executes
    only the `tile_a` side of the swap — see `SwapController`).
- `BoardGraph.swapped_tiles` — the last accepted swap's two tiles, reset in `PhasePlayerInput.enter`
  (start of each turn), filled by `SwapController` before handoff to physics. Lives on `board`, not
  `TurnContext`, since `board` is the only object actually threaded into every hook
  (`Effect.execute`, `TileBehavior.*`).
- `DetonateController` (`core/actions/`) — player direct-action controller (not a swap): double-click
  on a tile (`InputController` reads `InputEventMouseButton.double_click`) →
  `tile.is_manually_triggerable()` → `tile.manual_trigger(cell, board)`. Kept separate from
  `on_damage`/`on_splash_damage` specifically so manual detonation isn't constrained by whatever
  limits those two.
- A match of exactly `EffectResolveMatchGroup.ARROW_MATCH_SIZE` (4) or ≥ `BOMB_MATCH_THRESHOLD` (5)
  spawns a bonus: the whole group is destroyed normally (`EffectDestroyTile` per cell — same
  `on_matched`/splash cascade as an ordinary match, fully drained through the `resolver` before
  returning), and the anchor cell gets a bonus tile via `EffectSpawnArrowBlasterTile`/
  `EffectSpawnBombTile`/`EffectSpawnPrismTile`. Anchor = the group cell closest to its center of mass
  (not random or first — reads as "middle of the match"); by spawn time it's already empty (destroyed
  by the same cascade), so spawning can't be undone by someone else's splash. Exactly size 4
  guarantees a straight unbranched run (see `EffectResolveMatchGroup`'s class doc) — all cells share
  one `x` (vertical match) or one `y` (horizontal), which sets the spawned `ArrowBlasterCore` axis
  (`_blast_axis_for`, always perpendicular to the match axis). At ≥ `BOMB_MATCH_THRESHOLD`, the same
  "all cells share one `x` or `y`" check (`_is_straight_line`) decides bomb vs prism: a straight run
  longer than usual (5+ in a line) spawns a prism, an L/T/blob shape (two runs ≥3 merged on a shared
  cell) spawns a bomb. Threshold/size are computed on the honest group: `MatchFinder`'s flood-fill
  only merges adjacent "matched" cells into one group **if they mutually match** — otherwise two
  independent same-touching-but-different-color 3-matches would glue into one group and falsely spawn
  a bonus.
- A bomb can also randomly drop during gravity respawn (`WorldGenParams.bomb_spawn_chance` →
  `BoardGraph.bomb_spawn_chance`, used in `EffectSpawnTile`; doesn't affect initial board generation).
  `EffectSpawnBombTile`/`EffectSpawnArrowBlasterTile`/`EffectSpawnPrismTile`/`EffectSpawnTile` for a
  bonus tile always set `fall_distance = 0` — it appears in place (a pop-in) instead of falling from
  the top of the board. `EffectPlaceTile` (shared with combining, above) is the
  same idea for an already-built `Tile` rather than one built on the spot via a factory.

## Effects — a single cascade mechanism

- `Effect.execute(board) -> Array[Effect]` — an effect runs and may spawn more effects.
  `EffectResolver` drains the queue until empty, emitting a signal per step — `view` subscribes to
  play animations.
- Tile destruction, gravity, spawn, damage, bomb/arrow-blaster/prism blast — all `Effect` subclasses
  (`EffectDestroyTile`, `EffectGravityColumn`, `EffectSpawnTile`, `EffectSplashDamage`,
  `EffectBlastDamage`, `EffectBombBlast`, `EffectSpawnBombTile`, `EffectArrowBlast`,
  `EffectSpawnArrowBlasterTile`, `EffectPrismBlast`, `EffectSpawnPrismTile`, `EffectPlaceTile`,
  `EffectTriggerTile`, `EffectResolveMatchGroup`) — the shared cascade loop picks them up with zero
  special-casing.
- `EffectResolver.resolve()` is reentrant: no instance state (queue is a local var), so an effect can
  synchronously call `resolver.resolve(...)` again inside its own `execute()` (see
  `EffectResolveMatchGroup` — fully drains the group's destruction through the same resolver first, so
  `effect_applied` reaches `view` normally, then returns the bonus-spawn effect).
- `PhasePhysicsResolve` doesn't gate on "did this wave find a match" — gravity must run at least once
  on phase entry even if the wave found zero matches (a direct bomb trigger or someone else's blast can
  empty cells outside the match-search loop). Loop-continue condition:
  `not groups.is_empty() or ctx.board.has_empty_holdable_cell()`.

## Turns

- `TurnManager` runs the ordered `TurnPhase` list returned by the active `GameMode.build_phases()`.
  Infinite: `PhasePlayerInput → stubs → PhasePhysicsResolve`. Battle: `PhaseBattleTurnStart →
  PhaseCharacterInput → PhasePhysicsResolve → PhaseResolveCombatAction`. A new phase or order is an
  edit of the mode's list.
- `request_hold()` parks the loop at the end of the current cycle (animations finished) and emits
  `held`; `release()` resumes. Used by the editor and by mid-turn mode switches.
- `PhasePhysicsResolve.settle(ctx)` — the match/gravity loop, reusable outside the cycle (editor exit).
- Cross-frame waits (`BoardViewAnimationDriver.await_delay`, view tweens) are view-owned, never
  `SceneTree` timers: they respect pause and die with the scene on reload.

## View animation

The model resolves a whole wave synchronously; the view plays it back afterwards.

- `Effect.cause` (set by `EffectResolver`) links an effect to the one whose `execute()` returned it.
  Effects carry what the view needs (`EffectAppearTile.tile`/`fall_distance`/`reveal_distance`,
  `EffectGravityColumn.moves`, `EffectBlast.source`), so the view never diffs board state to guess events.
- `BoardView3D` is a thin root: `cells` (`CellLayer`), `tiles` (`TileLayer` + `TileMotion`), `vfx` (`VfxPool`),
  `BoardGeometry` for cell<->world math. `present_effect` (wired to `effect_applied`) queues effects that have a presenter.
  `await_settled()` — what `AnimationDriver.await_settle` calls — plays the queue with `WavePlayer`:
  effects grouped by depth along `cause`, one generation after another, each generation in parallel.
- `EffectPresenter` per effect type, registered in `BoardView3D._register_presenters` (like `EntityView`
  per entity type): `play(effect, stage)` starts the animation; it `await`s only what the effects it
  causes must wait for (a bomb's fuse via `fuse_finished(source)`, a projectile's `arrived`). Waiting is
  always on an animation finishing, never on a duration constant.
- `ActivityTracker` follows every view tween so a wave ends when the last one ends; a replaced tween must
  go through `cancel`. `refresh()` reconciles nodes with the board for changes that carry no effect
  (opening fill, swap, shuffle, world editor) and after each wave as a safety net.
- Falls are uniform acceleration (quad ease-in) per tile. Tile nodes are pooled by `TileView`
  (`release_node`); `VfxPool` pools, caps and light-budgets explosions and bolts (GL Compatibility/web).
- A new look for an effect = a new `EffectPresenter`; a new entity look = a new `EntityView`.

## Game modes and session

- `core/modes/`: `GameMode` → `InfiniteMode`, `BattleMode`. A mode supplies the phase list
  (`build_phases(ctx, level)`), generation params (`board_params(base, level)`) and HUD visibility.
- PvP is configuration, not a subclass: `BattleMode.new(name, ally_humans, enemy_humans,
  ally_budget_ratio, enemy_budget_ratio)` (PvP: N humans per side, budget 0 = no generated filler).
- What the start screen knows about a mode is a `ModeDefinition` (`core/modes/`, subclasses in
  `definitions/`, listed in `ModeCatalog`): title, `settings_schema()` (`SettingSpec`
  list — the setup form is built from it), `create_mode(settings)`, `world_params(settings)`,
  `start_level(settings)`. `RunConfig` = mode id + settings + progression `level`; it is everything a
  scene reload needs to rebuild the same game.
- `game/game_session.gd` (`GameSession.launch: RunConfig`, static) is the only state that survives a
  reload. Core never reads it; `GameRoot` passes values in. `SceneRouter` moves between the two
  top-level scenes: `game/menu_root.tscn` (start screen, the project's main scene) and
  `game/game_root.tscn`.
- `GameRoot.switch_mode()` rebuilds the `TurnManager` on the same board (mid-turn: on `held`); only
  the debug-build menu/editor toolbar uses it. Restart and the next battle reload the scene
  (`reload_current_scene()`), rebuilding every module from `GameSession.launch`.

## Profile and saves

- `core/profile/` (plain data, no file access): `ProfileData` (per-mode `ModeStats` + the last settings
  used in each setup form; `to_dict`/`from_dict`, `VERSION`), `ModeStats` (int counters with shared keys
  `runs`, `tiles`, `best_score`, `wins`, `losses`, `best_level`), `StatsRecorder` (self-subscribes to
  `ScoreTracker`, plus `note_level`/`note_battle_ended`; owner saves when `dirty`).
- `game/save_store.gd` is the only file access: `user://profile.json`, written to `.tmp` and renamed. JSON
  makes every number a float, so `from_dict` converts back to int. `GameSession.profile()` loads it once.
- A `ModeDefinition` picks what to show: `stat_specs()` (`StatSpec` key + label) and settings ranges that
  may depend on stats (`settings_schema(stats)`; Battle's start level is capped at the best level reached).
  `resolve_settings(saved, stats)` lays saved settings over the defaults, dropping unknown keys and
  clamping to today's ranges. `ModeSetupForm` shows the stats and hides settings with one possible value.
- Saving: `MenuRoot` on Start (remember settings, `runs`+1), `GameRoot` at each turn-cycle end, on
  `battle_ended` and in `_exit_tree`.

## Continue (per-mode run save)

- One slot per mode: `user://run_<mode>.json` = `RunSave` (`VERSION`, `RunConfig` + `GameSnapshot` data).
  `RunSave.from_dict` returns null for an unknown version or a malformed file, so a bad save is ignored.
- `GameSnapshot.capture(ctx, quests)` is taken in `GameRoot._save_run` on `turn_cycle_completed` — the only
  point where the board is settled and no action is pending — and skipped while the editor is open or the
  battle is over. It holds `BoardGraph.to_dict` (cells, tiles, colors, spawn chances, rng seed/state as
  strings), `ScoreTracker.to_dict`, `QuestManager.to_dict` and `BattleContext.to_dict` (characters with
  hp/shield/controller, initiative queue as roster indices).
- Everything with a class hierarchy has a codec instead of serializing object graphs: tiles save their
  factory recipe (`Tile.recipe`, `Tile.from_recipe`; `EntityCodec` dispatches by entity type), cells save
  `CellKind.id()` (`CellKindCodec`), characters save `controller.to_dict()` (`ControllerCodec`). A new tile
  kind / cell kind / controller = one line in its factory/codec; nothing else changes.
- Restore: `MenuRoot._on_continue` puts `run.game` into `GameSession.resume` and loads the game scene;
  `GameRoot` builds the board with `BoardGraph.from_dict` instead of generating, restores score and quests,
  and `_restore_battle` swaps the freshly rolled encounter for the saved one and puts the rng state back
  (the mode's `build_phases` consumed rng). Verified by replaying: a restored game plays out
  bit-identical to the uninterrupted one (battle, and infinite with detonations).
- The slot is overwritten at every cycle and deleted on `battle_ended`; Start/Restart leave it until the
  first new snapshot. The mode page shows Continue next to New game when a slot loads.

## Battle

- `core/characters/` (RefCounted): `Character` (side + `CharacterController`), `BattleContext`
  (rosters, `InitiativeQueue`, `actions`, `pending_action`/`pending_target`, signals, `level`,
  `power_multiplier`, `MAX_PER_SIDE = 5`), `CombatResolver`.
- Turn order: one queue per round, all living characters sorted by initiative (desc); each acts once.
- Actions (`core/characters/actions/`): `BattleAction` → `AttackAction` (crit grows with combo),
  `DefendAction` (shield on own side). Hooks: `display_name`, `targets_own_side`, `candidates`,
  `best_target`, `ai_priority`, `apply`. `BattleContext.actions` (first = default) drives the card
  buttons, the AI and the combat phase. A new action is a new subclass and one list entry.
- Targeting: `BattleContext` asks the active controller for `pending_target` on turn start and on
  action change, so the card shows "Action → target" for every character. A human click may pick any
  living card (friendly fire, shielding an enemy); `HumanController` keeps it while the action accepts
  it, else falls back to `best_target`.
- Controllers: `choose_action`, `choose_move`, `choose_target`. `AiController.skill`
  (`0.3 + 0.06/level`, max `0.95`) is the probability of each smart call (best move, most urgent
  action, best target); otherwise a random move, the default action, or a non-best target.
- Combat power = `BattleContext.power_of(actor, score_tracker)`: match points × `power_multiplier`
  (by board color count: 3 → 0.12, 4 → 0.4, 5 → 0.75, 6 → 1.0; few colors cause self-feeding
  cascades) + blast points × `ScoreTracker.BLAST_POWER_FACTOR` (0.3), then × the actor's
  `power_scale`. Combo factor `1 + combo_step × (combo_wave − 1)`; Battle sets `combo_step =
  0.25 + 0.05/level`, Infinite keeps 1.0.
- Progression: `RunConfig.level` +1 per victory. All level curves go through `LevelCurve`
  (`core/progression/`: `percent`, `linear`, `stepped`). Units grow by percent of their level-1 stats;
  the board grows from 6×6, 3 colors, no holes up to the menu settings.
- Units (`UnitType`): level-1 stat ranges, growth, `cost`, `min_level`; `hero()`, `devil()`,
  `enemy_catalog()`, `ally_catalog()`. `EncounterGenerator.build_side()` applies one rule to both
  sides: side size from `SLOT_UNLOCK_LEVELS`; human units enter first and pay their cost; remaining
  budget buys random unlocked units weighted by cost³. Budget = `BUDGET_PER_LEVEL × level × side
  ratio` (Battle 0.92/1.0, PvP 1.0/1.0).
- Unit cost reflects action economy: each unit is one board move per round, so N cheap units out-act
  one large unit with the same stat total. Costs are half-steps (cheap = 2), calibrated by equal-cost
  AI duels — see `.claude/skills/match3-battle/SKILL.md`.
- View (`view/battle/`): `BattleView`, `CharacterCard` read `ctx.battle` and send picks back through
  it. Action VFX (`view/packs/battle_fx_pack/`, scenes + shaders): charge aura on the active card (intensity = power relative to half the target's max HP, min 0.35), `BattleContext.action_launched`
  → `BattleFx` bolt to the target and burst; the phase waits `LAUNCH_SECONDS` before `apply`. Color
  comes from `BattleAction.visual_kind()` via the pack's `action_colors.tres` (core knows no colors). Victory → next level on a new board; defeat → retry the level.

## Procedural generation and serialization

- `WorldGenParams` (Resource) — generation params: size, color count, pit density/count, seed,
  `allow_enemies`/`allow_penalties` toggles, difficulty. `BoardGenerator` builds a `BoardGraph` and
  places tiles avoiding any starting matches.
- `BoardLayout` (Resource) — serializable layout (cell kinds + optional fixed tiles) for hand-built
  levels; saved/loaded via `ResourceSaver`/`ResourceLoader` as `.tres`.

## In-game world editor

- `BoardEditController` (`core/editor/`) mutates `BoardGraph` directly, bypassing effects, gated by
  `ctx.awaiting_player_input`. UI: `view/editor/` (`EditorModeController`, grid overlay, toolbar,
  cell/tile catalogs).
- Entry: `R` or the menu's "Editor (R)". Opens at once when idle; otherwise holds the turn manager
  and opens on `held`. Exit settles the edits (`PhasePhysicsResolve.settle`), resets the combo,
  restores input state and releases the manager — editing never costs a turn.
- Toolbar also sets the mode and the battle level (rebuilds the battle on the current board).
- Details and pitfalls: `.claude/skills/match3-world-editor/SKILL.md`.

## Moves, hint, shuffle

- `MoveFinder` (`core/board/`) lists every legal move (swap, splash trigger, combine, detonation)
  valued as `power_of` weighs it (no cascade simulation): `best_move`, `pick_move(skill)`,
  `has_move`. Used by AI turns, the hint and the shuffle.
- `BoardShuffler` permutes existing tiles until no match is present and a move exists (fallback:
  recolor plain tiles), so a shuffle never scores. `ShuffleController`: human button when no move,
  AI automatically; the turn continues.
- `MoveAssist` (`view/hud/`): Shuffle button when stuck; after 10 s idle, highlights the move an AI of
  the current level would play (best move outside battle).

## Game menu and HUD

- `ModeSelect` (`view/menu/`): the start screen — a button per mode and a schema-built setup page (`ModeSetupForm`).
  `GameMenu`: ☰ / Esc, pauses the tree, emits signals only: Resume, Settings (tile/board pack, applied
  at once — the live board swaps models, see `BoardView3D.reskin`), Restart, Main menu. `MenuKit`
  holds the shared builders, `ModeSetupForm` the schema-built form (presets + Advanced toggle).
- Orientation: on a portrait window `UiScale.fit()` swaps the base size to
  1080×1920, so UI keeps its size on phones. `BattleView` lays cards out as side columns (landscape)
  or rows (portrait: enemies above, allies below, compact cards); both are docked to the board edges.
  Infinite mode: `ScoreHud` always centered above the board; `QuestHud` (`BoxContainer`) is a column
  right of the board (landscape) or a row below it (portrait).
- Camera fit: `GameRoot._place_camera()` fits the board into the screen area left free by visible HUD
  (`hud_rects()` per view; each blocker cuts from the edge costing the smallest screen share) and
  centers it via `h_offset`/`v_offset`. Refit on resize and mode switch. A new HUD element must
  report its rect.

## Audio

- `Audio` (autoload, `view/audio/audio_director.gd`) is the only sound entry point; sounds are cue names
  looked up in the active audio pack's `AudioBank` (`view/packs/audio_pack/`), and a name the pack lacks is
  silent. Core never touches audio: effect sounds come from `EffectPresenter.cue_for` (played by
  `WavePlayer` with the animation) or from the presenter itself when timed inside it (landings, blast
  stages); board/HUD and battle events go through `BoardAudio`/`BattleAudio`; buttons and sliders are
  wired globally by the autoload. Volumes (Master/Music/Effects) live in `user://audio.cfg`.
- The packs are synthesized by `tools/gen_audio.py` (no samples, CC0), imported as ADPCM wav.
  Details and the "where does a new sound go" table: `.claude/skills/match3-audio/SKILL.md`.

## Build and export

- `export_presets.cfg`: macos-universal, linux-x86_64/arm64, windows-x86_64/arm64, web.
- `ci/export.py` exports presets locally or inside the `ci/Dockerfile` image;
  `.github/workflows/export.yml` runs it on push/PR (default set) or manually per preset. See
  `.claude/skills/ci-export/SKILL.md`.

## Naming

Code uses the generic word "tile" (not "crystal") — the concrete visual (crystal, gear, whatever) is
a `view`/art concern, not core's.

## Adding a new mechanic

See `.claude/skills/match3-add-mechanic/SKILL.md` — a short "new X → new file in Y" cheat sheet.
Every new effect presenter / `BattleAction` also needs its sound cue name (`match3-audio`).
