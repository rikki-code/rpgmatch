## Waits for an external swap attempt (SwapController.try_swap, driven by
## view/input_controller.gd). Advances the turn only when a swap is
## actually accepted.
class_name PhasePlayerInput
extends TurnPhase

func is_instant() -> bool:
	return false

func enter(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = true

func exit(ctx: TurnContext) -> void:
	ctx.awaiting_player_input = false
