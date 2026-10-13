## Hits the target for the full power (hybrid — always lands); combo raises
## the crit chance.
class_name AttackAction
extends BattleAction

## A modest combo (x3-x4) gives a real but not guaranteed crit shot.
const CRIT_CHANCE_PER_COMBO_STEP := 0.08
const MAX_CRIT_CHANCE := 0.5

func display_name() -> String:
	return "Attack"

func ai_priority(_actor: Character, _battle: BattleContext) -> float:
	return 0.5

func best_target(actor: Character, battle: BattleContext) -> Character:
	var best: Character = null
	for character in candidates(actor, battle):
		if best == null or character.effective_hp() < best.effective_hp():
			best = character
	return best

func apply(actor: Character, target: Character, power: int, combo_factor: float, battle: BattleContext) -> void:
	var crit_chance := minf(actor.base_crit_chance + (combo_factor - 1.0) * CRIT_CHANCE_PER_COMBO_STEP, MAX_CRIT_CHANCE)
	battle.resolver.resolve(CombatAction.new(actor, target, power, crit_chance))
