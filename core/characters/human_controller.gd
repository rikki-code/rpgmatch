## Player-controlled: action comes from the card's menu
## (BattleContext.select_action), one target from clicking any card (used
## by either action, so friendly fire / shielding an enemy are possible), the
## move from the board itself.
class_name HumanController
extends CharacterController

func is_human() -> bool:
	return true

func choose_target(actor: Character, battle: BattleContext) -> Character:
	if battle.human_target != null and battle.human_target.is_alive():
		return battle.human_target
	return super.choose_target(actor, battle)

func choose_shield_target(actor: Character, battle: BattleContext) -> Character:
	if battle.human_target != null and battle.human_target.is_alive():
		return battle.human_target
	return actor
