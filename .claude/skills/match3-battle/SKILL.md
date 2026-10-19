---
name: match3-battle
description: >
  Battle system of the match-3 RPG: characters, controllers, actions,
  targeting, combat power, AI skill, units/encounters, progression, and how
  to calibrate unit costs. Use when touching core/characters, core/modes
  (battle), core/progression, view/battle, or battle balance.
---

## Model

- One shared board. Each character acts once per round in initiative order: action → board move →
  the move's points become the action's power (`PhaseResolveCombatAction`).
- `Character`: side + `CharacterController` (composition). `HumanController` waits for input;
  `AiController` decides with `skill`.
- `BattleContext` owns rosters, the queue, `actions`, `pending_action`, `pending_target`, signals.
  It picks `pending_target` through the active controller on turn start and on action change.

## Files

| Concern | File |
|---|---|
| Characters, context, resolver, queue | `core/characters/` |
| Actions | `core/characters/actions/` (`BattleAction`, `AttackAction`, `DefendAction`) |
| Units, encounters | `core/characters/unit_type.gd`, `encounter_generator.gd` |
| Level curves | `core/progression/level_curve.gd` |
| Mode (phases, board params, budgets) | `core/modes/battle_mode.gd` |
| Phases | `core/turns/phases/phase_battle_turn_start.gd`, `phase_character_input.gd`, `phase_resolve_combat_action.gd` |
| Move valuation | `core/board/move_finder.gd` |
| View | `view/battle/` (`BattleView`, `CharacterCard`, `BattleFx` — places/starts pack VFX); card power uses `RollingCounter` |
| VFX pack | `view/packs/battle_fx_pack/standard_pack/` (aura, bolt, burst scenes, shaders, action colors) — see `.claude/skills/match3-view-packs/SKILL.md` |

## Recipes

| Want | Do |
|---|---|
| New action (heal, ability) | Subclass `BattleAction` (incl. `visual_kind()`); add an instance to `BattleContext.actions`; add its color to the pack's `action_colors.tres`. |
| New unit | One `UnitType.new(...)` line in a catalog; pick its cost, then calibrate (below). |
| New controller (network, scripted) | Subclass `CharacterController`; override `choose_action/move/target`. |
| New battle variant (co-op, boss) | Configure `BattleMode.new(name, ally_humans, enemy_humans, ally_ratio, enemy_ratio)` in `GameRoot.available_modes`. Not a subclass. |
| New level-scaled value | `LevelCurve.percent/linear/stepped`. Never hand-rolled. |

## Rules

- No `if` on action type; actions carry their own targeting, AI priority and effect.
- The level is passed as a parameter (`build_phases(ctx, level)`); never stored on a mode.
- AI target and move mistakes exclude the best option, so `skill` is the exact best-pick rate.
- `MoveFinder` must weigh points exactly as `BattleContext.power_of` (match × color multiplier,
  blast × `BLAST_POWER_FACTOR`).

## Balance

- Worth is not `hp × power`: each unit is one board move per round, so many cheap units out-act one
  expensive unit (action economy).
- Costs are half-steps: cheap = 2; tier 2 = 4 (≈2 cheap), tier 3 = 5 (≈2.5), tier 4 = 6 (slightly
  over 3); hero/devil = 4. Same-cost units unlock at the same level on both sides.
- Calibration: duel a unit against N cheap units of equal total cost, all AI at skill 0.95, 6 colors,
  ≥40 games; adjust hp and power by one common factor until the win rate matches the intended worth.
- Duel/sim pattern: a `SceneTree` script building `TurnContext` + `BattleContext` by hand with the
  four battle phases (see `.claude/skills/godot-verify/SKILL.md`, "Headless simulations").

## Shader pitfall

Never scroll noise by `velocity * TIME`: inputs grow with play time and float precision turns the
pattern into grainy streaks within minutes (fresh test runs look fine). Use `energy_time(TIME)` and
`energy_flow_fbm(p, velocity, time)` from `energy_noise.gdshaderinc` (bounded two-phase cross-fade).
To check, temporarily offset time (`energy_time(TIME + 590.0)`) and screenshot.

GL Compatibility compiles a shader on its first draw (~4 frame hitch): a new pack effect must be
played once in `BattleFx._warm_up()` (offscreen `SubViewport`, nothing reaches the screen). Measure with per-frame deltas across repeated runs.

## Power-driven visuals

Every power-dependent visual (charge aura, bolt, burst) takes one 0..1 value from
`BattleView._charge_intensity()` (power vs half the target's max HP, min `MIN_CHARGE`); card hit punch
scales with damage / max HP. A new effect takes the same value — never its own scale.
