## Plays the board like the player does (MoveFinder), but only finds the
## best move `skill` of the time — grows with level, so early bots blunder.
## Attacks the opponent with the least hp + shield `skill` of the time,
## otherwise a random one (never its own side). Shields an ally (or itself)
## that's about to die — noticing it `skill` of the time.
class_name AiController
extends CharacterController

## HP + shield below this share of max HP = "about to die".
const DANGER_RATIO := 0.3
const BASE_SKILL := 0.3
const SKILL_PER_LEVEL := 0.06
const MAX_SKILL := 0.95

var skill: float

func _init(p_skill: float = MAX_SKILL) -> void:
	skill = p_skill

static func skill_for_level(level: int) -> float:
	return minf(BASE_SKILL + SKILL_PER_LEVEL * (level - 1), MAX_SKILL)

func choose_move(board: BoardGraph, battle: BattleContext, rng: RandomNumberGenerator) -> MoveFinder.Move:
	return MoveFinder.pick_move(board, skill, rng, battle.power_multiplier)

func choose_action_type(actor: Character, battle: BattleContext) -> BattleContext.ActionType:
	var wounded := choose_shield_target(actor, battle)
	if _effective_hp_ratio(wounded) < DANGER_RATIO and battle.resolver.rng.randf() < skill:
		return BattleContext.ActionType.DEFEND
	return BattleContext.ActionType.ATTACK

func choose_shield_target(actor: Character, battle: BattleContext) -> Character:
	var best := actor
	for ally in battle.allies_of(actor):
		if ally.is_alive() and _effective_hp_ratio(ally) < _effective_hp_ratio(best):
			best = ally
	return best

static func _effective_hp_ratio(character: Character) -> float:
	return float(character.hp + character.shield) / character.max_hp

func choose_target(actor: Character, battle: BattleContext) -> Character:
	var living := battle.opponents_of(actor).filter(func(c: Character) -> bool: return c.is_alive())
	if living.is_empty():
		return null
	var rng := battle.resolver.rng
	if rng.randf() >= skill:
		return living[rng.randi_range(0, living.size() - 1)]
	var best: Character = living[0]
	for character: Character in living:
		if character.hp + character.shield < best.hp + best.shield:
			best = character
	return best
