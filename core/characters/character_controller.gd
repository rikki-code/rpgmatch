## Who drives a character's turn. Every turn is the same shape for everyone
## (pick an action, make a board move, spend the points — see the battle
## phases); a controller only decides the parts a human would pick by hand.
## A network controller later plugs in the same way.
class_name CharacterController
extends RefCounted

## True = PhaseCharacterInput unlocks board input and waits for the player.
func is_human() -> bool:
	return false

func choose_action_type(_actor: Character, _battle: BattleContext) -> BattleContext.ActionType:
	return BattleContext.ActionType.ATTACK

func choose_target(actor: Character, battle: BattleContext) -> Character:
	return battle.first_living(battle.opponents_of(actor))
