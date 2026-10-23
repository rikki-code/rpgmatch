## Who drives a character's turn. Every turn is the same shape for everyone
## (pick an action, make a board move, spend the points — see the battle
## phases); a controller only decides the parts a human would pick by hand.
## RemoteController (the opponent of an online match) plugs in the same way.
class_name CharacterController
extends RefCounted

const AI_THINK_SECONDS := 0.6
const AI_PREVIEW_SECONDS := 0.7

## Saved with the character; a new controller also joins ControllerCodec.
func to_dict() -> Dictionary:
	return {"type": "controller"}

## True = PhaseCharacterInput unlocks board input and waits for the player.
func is_human() -> bool:
	return false

## A person plays this character, here or across the network.
func is_player() -> bool:
	return is_human()

## Played by someone on the other end of an online match.
func is_remote() -> bool:
	return false

## The whole board move of a character nobody controls locally; the default is the bot.
## Both perform_* hand the turn on themselves; only a refused move doesn't.
func take_turn(ctx: TurnContext) -> void:
	var actor := ctx.battle.active_character
	await ctx.animation_driver.await_delay(AI_THINK_SECONDS)
	ctx.battle.select_action(choose_action(actor, ctx.battle))
	var rng := ctx.battle.resolver.rng
	var move := choose_move(ctx.board, ctx.battle, rng)
	if move == null:
		ctx.shuffle_controller.perform_shuffle()
		await ctx.animation_driver.await_delay(AI_THINK_SECONDS)
		move = choose_move(ctx.board, ctx.battle, rng)
	if move == null:
		ctx.turn_manager.notify_phase_done()
		return
	ctx.battle.ai_move_chosen.emit(move.cell_a, move.cell_b)
	await ctx.animation_driver.await_delay(AI_PREVIEW_SECONDS)
	var done: bool
	if move.kind == MoveFinder.Move.Kind.DETONATE:
		done = await ctx.detonate_controller.perform_detonate(move.cell_a)
	else:
		done = await ctx.swap_controller.perform_swap(move.cell_a, move.cell_b)
	if not done:
		ctx.turn_manager.notify_phase_done()

func choose_action(_actor: Character, battle: BattleContext) -> BattleAction:
	return battle.actions[0]

## Board move for a non-human turn; null = no legal move.
func choose_move(board: BoardGraph, battle: BattleContext, _rng: RandomNumberGenerator) -> MoveFinder.Move:
	return MoveFinder.best_move(board, battle.power_multiplier)

func choose_target(actor: Character, action: BattleAction, battle: BattleContext) -> Character:
	return action.best_target(actor, battle)
