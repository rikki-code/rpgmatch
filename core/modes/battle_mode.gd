## Puzzle-Quest-style battle on the shared board: every character, player
## or AI, takes a turn in initiative order — pick an action, make a swap,
## the turn's points become that action's power (see docs/plan.md, "Battle
## mode"). Each battle is one `level`: everyone's stats grow with it and
## EncounterGenerator fills each side around its human-controlled units
## (hero; plus the Devil in PvP — same mode, different data). The board grows
## with the level too (board_params).
class_name BattleMode
extends GameMode

## Board at level 1: small, no holes, 3 colors; grows up to the menu settings.
const START_WIDTH := 6
const START_HEIGHT := 6
const START_COLORS := 3
const LEVELS_PER_WIDTH := 2
const LEVELS_PER_HEIGHT := 3
const LEVELS_PER_COLOR := 2
const LEVELS_PER_PIT := 1
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

var _name: String
## Human-controlled units heading each side; generated units fill the rest.
var ally_humans: Array[UnitType]
var enemy_humans: Array[UnitType]
## Unit costs are in half-steps (cheap unit = 2, see UnitType).
const BUDGET_PER_LEVEL := 2
## Share of the level each side may spend (catalogs themselves are balanced):
## uneven = a handicap (Battle: player vs AI), equal = a fair PvP.
var ally_budget_ratio: float
var enemy_budget_ratio: float

func _init(p_name: String, p_ally_humans: Array[UnitType], p_enemy_humans: Array[UnitType], p_ally_budget_ratio: float, p_enemy_budget_ratio: float) -> void:
	_name = p_name
	ally_humans = p_ally_humans
	enemy_humans = p_enemy_humans
	ally_budget_ratio = p_ally_budget_ratio
	enemy_budget_ratio = p_enemy_budget_ratio

func display_name() -> String:
	return _name

func build_phases(ctx: TurnContext, level: int) -> Array[TurnPhase]:
	ctx.battle = _build_battle(ctx.board, level)
	ctx.score_tracker.combo_step = LevelCurve.linear(BASE_COMBO_STEP, COMBO_STEP_PER_LEVEL, level, MAX_COMBO_STEP)
	return [
		PhaseBattleTurnStart.new(),
		PhaseCharacterInput.new(),
		PhasePhysicsResolve.new(),
		PhaseResolveCombatAction.new(),
	]

func board_params(base: WorldGenParams, level: int) -> WorldGenParams:
	var params: WorldGenParams = base.duplicate()
	params.width = LevelCurve.stepped(START_WIDTH, LEVELS_PER_WIDTH, level, maxi(base.width, START_WIDTH))
	params.height = LevelCurve.stepped(START_HEIGHT, LEVELS_PER_HEIGHT, level, maxi(base.height, START_HEIGHT))
	params.color_count = LevelCurve.stepped(START_COLORS, LEVELS_PER_COLOR, level, maxi(base.color_count, START_COLORS))
	var pit_cap := mini(base.pit_count, floori(params.width * params.height * MAX_PIT_RATIO))
	params.pit_count = LevelCurve.stepped(0, LEVELS_PER_PIT, level, pit_cap)
	return params

func shows_score_hud() -> bool:
	return false

func shows_quest_hud() -> bool:
	return false

func shows_battle_view() -> bool:
	return true

func _build_battle(board: BoardGraph, level: int) -> BattleContext:
	var battle := BattleContext.new(CombatResolver.new(board.rng))
	battle.level = level
	battle.power_multiplier = POWER_MULTIPLIER_BY_COLORS.get(board.colors.size(), 1.0)
	battle.allies = EncounterGenerator.build_side(ally_humans, UnitType.ally_catalog(), Character.Side.ALLY, level, roundi(level * BUDGET_PER_LEVEL * ally_budget_ratio), board.rng)
	battle.enemies = EncounterGenerator.build_side(enemy_humans, UnitType.enemy_catalog(), Character.Side.ENEMY, level, roundi(level * BUDGET_PER_LEVEL * enemy_budget_ratio), board.rng)
	return battle
