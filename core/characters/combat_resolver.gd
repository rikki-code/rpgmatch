## Hybrid resolution: power always lands as damage, crit_chance (driven by
## the action's own points/combo) rolls for a bonus multiplier on top.
class_name CombatResolver
extends RefCounted

signal action_resolved(action: CombatAction, damage: int, is_crit: bool)

const CRIT_MULTIPLIER := 1.5

var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng

func resolve(action: CombatAction) -> void:
	if action == null or action.target == null or not action.target.is_alive():
		return
	var is_crit := rng.randf() < action.crit_chance
	var damage := roundi(action.power * (CRIT_MULTIPLIER if is_crit else 1.0))
	action.target.apply_damage(damage)
	action_resolved.emit(action, damage, is_crit)
