## Who drives a character's turn. Every turn is the same shape for everyone
## (pick an action, make a board move, spend the points — see the battle
## phases); a controller only decides the parts a human would pick by hand.
## A network controller later plugs in the same way.
class_name CharacterController
extends RefCounted

## Saved with the character; a new controller also joins ControllerCodec.
func to_dict() -> Dictionary:
	return {"type": "controller"}

## True = PhaseCharacterInput unlocks board input and waits for the player.
func is_human() -> bool:
	return false

func choose_action(_actor: Character, battle: BattleContext) -> BattleAction:
	return battle.actions[0]

## Board move for a non-human turn; null = no legal move.
func choose_move(board: BoardGraph, battle: BattleContext, _rng: RandomNumberGenerator) -> MoveFinder.Move:
	return MoveFinder.best_move(board, battle.power_multiplier)

func choose_target(actor: Character, action: BattleAction, battle: BattleContext) -> Character:
	return action.best_target(actor, battle)
