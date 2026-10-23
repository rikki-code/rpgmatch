## The active character's board move. A human gets board input unlocked
## and the turn waits for their swap; an AI picks its action and a move
## itself (CharacterController.take_turn: a bot, or the opponent of an online
## match), announced first via BattleContext.ai_move_chosen so the view can show
## it before it happens.
class_name PhaseCharacterInput
extends TurnPhase

func is_instant() -> bool:
	return false

func enter(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = ctx.battle.active_character.controller.is_human()

func execute(ctx: TurnContext) -> void:
	var actor := ctx.battle.active_character
	if actor.controller.is_human():
		return
	await actor.controller.take_turn(ctx)

func exit(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = false
