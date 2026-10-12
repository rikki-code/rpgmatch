## Puzzle-Quest-style battle on the shared board: every character, player
## or AI, takes a turn in initiative order — pick an action, make a swap,
## the turn's points become that action's power (see docs/plan.md, "Battle
## mode"). Each battle is one `level`: the hero's stats grow with it and
## EncounterGenerator picks the enemies; the hero always starts at full HP.
class_name BattleMode
extends GameMode

const HERO_BASE_HP := 100
const HERO_HP_GROWTH_PER_LEVEL := 0.12
const HERO_BASE_POWER := 0.2
const HERO_POWER_GROWTH_PER_LEVEL := 0.08

var level := 1

func display_name() -> String:
	return "Battle"

func build_phases(ctx: TurnContext) -> Array[TurnPhase]:
	ctx.battle = _build_battle(ctx.board)
	return [
		PhaseBattleTurnStart.new(),
		PhaseCharacterInput.new(),
		PhasePhysicsResolve.new(),
		PhaseResolveCombatAction.new(),
	]

func shows_score_hud() -> bool:
	return false

func shows_quest_hud() -> bool:
	return false

func shows_battle_view() -> bool:
	return true

func _build_battle(board: BoardGraph) -> BattleContext:
	var battle := BattleContext.new(CombatResolver.new(board.rng))
	battle.level = level
	var steps := level - 1
	var hero_hp := roundi(HERO_BASE_HP * (1.0 + HERO_HP_GROWTH_PER_LEVEL * steps))
	var hero_power := HERO_BASE_POWER * (1.0 + HERO_POWER_GROWTH_PER_LEVEL * steps)
	battle.allies.append(Character.new("Hero", Character.Side.ALLY, hero_hp, 12, hero_power, HumanController.new()))
	battle.enemies = EncounterGenerator.generate(level, board.rng)
	return battle
