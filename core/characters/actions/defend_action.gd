## Banks the power as shield on self or an ally; AI reaches for it when
## someone on its side is about to die.
class_name DefendAction
extends BattleAction

## (hp + shield) below this share of max HP = "about to die".
const DANGER_RATIO := 0.3

func display_name() -> String:
	return "Defend"

func visual_kind() -> StringName:
	return &"defend"

func targets_own_side() -> bool:
	return true

func ai_priority(actor: Character, battle: BattleContext) -> float:
	var target := best_target(actor, battle)
	return 1.0 if target != null and _hp_ratio(target) < DANGER_RATIO else 0.0

func best_target(actor: Character, battle: BattleContext) -> Character:
	var best: Character = null
	for character in candidates(actor, battle):
		if best == null or _hp_ratio(character) < _hp_ratio(best):
			best = character
	return best

func apply(_actor: Character, target: Character, power: int, _combo_factor: float, battle: BattleContext) -> void:
	target.shield += power
	battle.shield_gained.emit(target, power)

static func _hp_ratio(character: Character) -> float:
	return float(character.effective_hp()) / character.max_hp
