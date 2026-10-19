## Spends the turn's board points on the active character's chosen
## BattleAction (attack, defend, ...). Same rules for player and AI.
class_name PhaseResolveCombatAction
extends TurnPhase

## Time the view gets to fly the action from actor to target before it lands.
const LAUNCH_SECONDS := 0.45
const SHOW_RESULT_SECONDS := 0.6

func execute(ctx: TurnContext) -> void:
	var battle := ctx.battle
	var actor := battle.active_character
	var power := battle.power_of(actor, ctx.score_tracker)
	if power <= 0:
		return
	var target := battle.pending_target
	if target == null or not target.is_alive():
		return
	battle.action_launched.emit(actor, target, battle.pending_action)
	await ctx.animation_driver.await_delay(LAUNCH_SECONDS)
	battle.pending_action.apply(actor, target, power, ctx.score_tracker.combo_factor(), battle)
	await ctx.animation_driver.await_delay(SHOW_RESULT_SECONDS)
