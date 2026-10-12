## One character's turn: target + power + crit chance. Same shape whether
## it came from an AI controller or from the player's board points (see
## PhaseResolvePlayerCombat) — CombatResolver doesn't care which.
class_name CombatAction
extends RefCounted

var actor: Character
var target: Character
var power: int
var crit_chance: float

func _init(p_actor: Character, p_target: Character, p_power: int, p_crit_chance: float = 0.0) -> void:
	actor = p_actor
	target = p_target
	power = p_power
	crit_chance = p_crit_chance
