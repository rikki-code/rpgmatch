## Spends the turn's board points on the active character's action: ATTACK
## hits its target (hybrid — power always lands, combo raises crit chance),
## DEFEND banks the same power as shield on self or an ally. Same rules for
## player and AI.
class_name PhaseResolveCombatAction
extends TurnPhase

## A modest combo (x3-x4) gives a real but not guaranteed crit shot.
const CRIT_CHANCE_PER_COMBO_STEP := 0.08
const MAX_CRIT_CHANCE := 0.5
const SHOW_RESULT_SECONDS := 0.6

func execute(ctx: TurnContext) -> void:
	var battle := ctx.battle
	var actor := battle.active_character
	var power := battle.power_of(actor, ctx.score_tracker)
	if power <= 0:
		return
	if battle.pending_action == BattleContext.ActionType.DEFEND:
		var recipient := actor.controller.choose_shield_target(actor, battle)
		recipient.shield += power
		battle.shield_gained.emit(recipient, power)
	else:
		var target := actor.controller.choose_target(actor, battle)
		if target == null:
			return
		var crit_chance := minf(actor.base_crit_chance + (ctx.score_tracker.combo_factor() - 1.0) * CRIT_CHANCE_PER_COMBO_STEP, MAX_CRIT_CHANCE)
		battle.resolver.resolve(CombatAction.new(actor, target, power, crit_chance))
	await ctx.animation_driver.await_delay(SHOW_RESULT_SECONDS)
