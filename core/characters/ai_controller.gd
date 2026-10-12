## Plays the board like the player does (move picked by AiSwapPicker).
## Attacks the weakest opponent; sometimes defends when low on HP.
class_name AiController
extends CharacterController

const LOW_HP_RATIO := 0.35
const DEFEND_CHANCE_WHEN_LOW := 0.5

func choose_action_type(actor: Character, battle: BattleContext) -> BattleContext.ActionType:
	var low_hp := float(actor.hp) / actor.max_hp < LOW_HP_RATIO
	if low_hp and actor.shield == 0 and battle.resolver.rng.randf() < DEFEND_CHANCE_WHEN_LOW:
		return BattleContext.ActionType.DEFEND
	return BattleContext.ActionType.ATTACK

func choose_target(actor: Character, battle: BattleContext) -> Character:
	var best: Character = null
	for character in battle.opponents_of(actor):
		if character.is_alive() and (best == null or character.hp < best.hp):
			best = character
	return best
