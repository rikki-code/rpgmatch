## Plays like the player does, but only makes the smart call `skill` of the
## time — grows with level, so early bots blunder: the best move
## (MoveFinder), the most urgent action (BattleAction.ai_priority), the best
## target; otherwise a random move / the default action / a random target.
class_name AiController
extends CharacterController

const BASE_SKILL := 0.3
const SKILL_PER_LEVEL := 0.06
const MAX_SKILL := 0.95

var skill: float

func _init(p_skill: float = MAX_SKILL) -> void:
	skill = p_skill

static func skill_for_level(level: int) -> float:
	return LevelCurve.linear(BASE_SKILL, SKILL_PER_LEVEL, level, MAX_SKILL)

func choose_move(board: BoardGraph, battle: BattleContext, rng: RandomNumberGenerator) -> MoveFinder.Move:
	return MoveFinder.pick_move(board, skill, rng, battle.power_multiplier)

func choose_action(actor: Character, battle: BattleContext) -> BattleAction:
	var best: BattleAction = battle.actions[0]
	for action in battle.actions:
		if action.ai_priority(actor, battle) > best.ai_priority(actor, battle):
			best = action
	return best if _smart(battle) else battle.actions[0]

func choose_target(actor: Character, action: BattleAction, battle: BattleContext) -> Character:
	if _smart(battle):
		return action.best_target(actor, battle)
	var candidates := action.candidates(actor, battle)
	return null if candidates.is_empty() else candidates[battle.resolver.rng.randi_range(0, candidates.size() - 1)]

func _smart(battle: BattleContext) -> bool:
	return battle.resolver.rng.randf() < skill
