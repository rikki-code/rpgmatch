## The active character's board move. A human gets board input unlocked
## and the turn waits for their swap; an AI picks its action and a move
## itself (its controller's skill decides how good), announced first via
## BattleContext.ai_move_chosen so the view can show it before it happens.
## With no move left the AI shuffles first, like the player's Shuffle button.
class_name PhaseCharacterInput
extends TurnPhase

const AI_THINK_SECONDS := 0.6
const AI_PREVIEW_SECONDS := 0.7

func is_instant() -> bool:
	return false

func enter(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = ctx.battle.active_character.controller.is_human()

func execute(ctx: TurnContext) -> void:
	var actor := ctx.battle.active_character
	if actor.controller.is_human():
		return
	await ctx.animation_driver.await_delay(AI_THINK_SECONDS)
	ctx.battle.select_action(actor.controller.choose_action_type(actor, ctx.battle))
	var rng := ctx.battle.resolver.rng
	var move := actor.controller.choose_move(ctx.board, ctx.battle, rng)
	if move == null:
		ctx.shuffle_controller.perform_shuffle()
		await ctx.animation_driver.await_delay(AI_THINK_SECONDS)
		move = actor.controller.choose_move(ctx.board, ctx.battle, rng)
	if move == null:
		ctx.turn_manager.notify_phase_done()
		return
	ctx.battle.ai_move_chosen.emit(move.cell_a, move.cell_b)
	await ctx.animation_driver.await_delay(AI_PREVIEW_SECONDS)
	# Both perform_* hand the turn on themselves; only a refused move doesn't.
	var done: bool
	if move.kind == MoveFinder.Move.Kind.DETONATE:
		done = await ctx.detonate_controller.perform_detonate(move.cell_a)
	else:
		done = await ctx.swap_controller.perform_swap(move.cell_a, move.cell_b)
	if not done:
		ctx.turn_manager.notify_phase_done()

func exit(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = false
