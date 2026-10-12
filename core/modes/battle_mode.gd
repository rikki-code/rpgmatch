## Puzzle-Quest-style battle on the shared board: every character, player
## or AI, takes a turn in initiative order — pick an action, make a swap,
## the turn's points become that action's power (see docs/plan.md, "Battle
## mode"). Builds a placeholder test roster each time it's entered.
class_name BattleMode
extends GameMode

func display_name() -> String:
	return "Battle"

func build_phases(ctx: TurnContext) -> Array[TurnPhase]:
	ctx.battle = _build_test_battle(ctx.board)
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

func _build_test_battle(board: BoardGraph) -> BattleContext:
	var battle := BattleContext.new(CombatResolver.new(board.rng))
	battle.allies.append(Character.new("Hero", Character.Side.ALLY, 100, 12, 0.2, HumanController.new()))
	battle.enemies.append(Character.new("Goblin", Character.Side.ENEMY, 60, 10, 0.2, AiController.new()))
	battle.enemies.append(Character.new("Slime", Character.Side.ENEMY, 45, 6, 0.15, AiController.new()))
	return battle
