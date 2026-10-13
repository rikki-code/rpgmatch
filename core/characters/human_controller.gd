## Player-controlled: action comes from the card's menu
## (BattleContext.select_action), the target from clicking any card (friendly
## fire / shielding an enemy are possible), the move from the board itself.
class_name HumanController
extends CharacterController

func is_human() -> bool:
	return true

## Keeps the clicked target while the action can take it; otherwise (e.g. an
## enemy when switching to Defend) falls back to the action's best pick.
func choose_target(actor: Character, action: BattleAction, battle: BattleContext) -> Character:
	var current := battle.pending_target
	if current != null and action.candidates(actor, battle).has(current):
		return current
	return super.choose_target(actor, action, battle)
