## Puzzle-Quest-style battle on the shared board: every character, player
## or AI, takes a turn in initiative order — pick an action, make a swap,
## the turn's points become that action's power (see docs/plan.md, "Battle
## mode"). Each battle is one `level`: the hero's stats grow with it and
## EncounterGenerator picks the enemies and recruits; the hero always starts
## at full HP. The board grows with the level too (board_params).
class_name BattleMode
extends GameMode

const HERO_BASE_HP := 100
const HERO_HP_GROWTH_PER_LEVEL := 0.12
const HERO_BASE_POWER := 0.2
const HERO_POWER_GROWTH_PER_LEVEL := 0.08

## Board at level 1: small, no holes, 3 colors; grows up to the menu settings.
const START_WIDTH := 6
const START_HEIGHT := 6
const START_COLORS := 3
const LEVELS_PER_WIDTH := 2
const LEVELS_PER_HEIGHT := 3
const LEVELS_PER_COLOR := 2
const PITS_PER_LEVEL := 1.0
## Pits never take more than this share of the board.
const MAX_PIT_RATIO := 0.15
## Few colors = self-feeding cascades: measured median points per turn
## (AI vs AI) ~250 at 3 colors, ~80 at 4, ~40 at 5, ~30 at 6+. Scales
## match points -> power back to the 6-color baseline (BattleContext.power_of);
## blast points are exempt.
const POWER_MULTIPLIER_BY_COLORS := {3: 0.12, 4: 0.4, 5: 0.75}
## Combo grows slowly early (x1, x1.25, x1.5...) and steeper with the level.
const BASE_COMBO_STEP := 0.25
const COMBO_STEP_PER_LEVEL := 0.05
const MAX_COMBO_STEP := 1.0

var level := 1

func display_name() -> String:
	return "Battle"

func build_phases(ctx: TurnContext) -> Array[TurnPhase]:
	ctx.battle = _build_battle(ctx.board)
	ctx.score_tracker.combo_step = minf(BASE_COMBO_STEP + COMBO_STEP_PER_LEVEL * (level - 1), MAX_COMBO_STEP)
	return [
		PhaseBattleTurnStart.new(),
		PhaseCharacterInput.new(),
		PhasePhysicsResolve.new(),
		PhaseResolveCombatAction.new(),
	]

func board_params(base: WorldGenParams) -> WorldGenParams:
	var steps := level - 1
	var params: WorldGenParams = base.duplicate()
	params.width = mini(START_WIDTH + floori(steps / float(LEVELS_PER_WIDTH)), maxi(base.width, START_WIDTH))
	params.height = mini(START_HEIGHT + floori(steps / float(LEVELS_PER_HEIGHT)), maxi(base.height, START_HEIGHT))
	params.color_count = mini(START_COLORS + floori(steps / float(LEVELS_PER_COLOR)), maxi(base.color_count, START_COLORS))
	var pit_cap := mini(base.pit_count, floori(params.width * params.height * MAX_PIT_RATIO))
	params.pit_count = mini(floori(steps * PITS_PER_LEVEL), pit_cap)
	return params

func shows_score_hud() -> bool:
	return false

func shows_quest_hud() -> bool:
	return false

func shows_battle_view() -> bool:
	return true

func _build_battle(board: BoardGraph) -> BattleContext:
	var battle := BattleContext.new(CombatResolver.new(board.rng))
	battle.level = level
	battle.power_multiplier = POWER_MULTIPLIER_BY_COLORS.get(board.colors.size(), 1.0)
	var steps := level - 1
	var hero_hp := roundi(HERO_BASE_HP * (1.0 + HERO_HP_GROWTH_PER_LEVEL * steps))
	var hero_power := HERO_BASE_POWER * (1.0 + HERO_POWER_GROWTH_PER_LEVEL * steps)
	battle.allies.append(Character.new("Hero", Character.Side.ALLY, hero_hp, 12, hero_power, HumanController.new()))
	battle.allies.append_array(EncounterGenerator.allies(level, board.rng))
	battle.enemies = EncounterGenerator.enemies(level, board.rng)
	return battle
