## One thing a character can spend its turn's power on (see
## PhaseResolveCombatAction). New action = new subclass in
## BattleContext.actions; nothing else branches on which one it is.
class_name BattleAction
extends RefCounted

func display_name() -> String:
	return ""

## Picks from the actor's own side (shield, heal) instead of opponents.
func targets_own_side() -> bool:
	return false

## How much an AI wants this action right now; the highest wins (AiController).
func ai_priority(_actor: Character, _battle: BattleContext) -> float:
	return 0.0

## The sensible pick — AI target when it doesn't blunder, human default.
func best_target(_actor: Character, _battle: BattleContext) -> Character:
	return null

func apply(_actor: Character, _target: Character, _power: int, _combo_factor: float, _battle: BattleContext) -> void:
	pass

func candidates(actor: Character, battle: BattleContext) -> Array[Character]:
	return battle.living(battle.allies_of(actor) if targets_own_side() else battle.opponents_of(actor))
