## "No moves left" escape hatch: reshuffles the board (BoardShuffler) without
## ending the turn — the shuffling character then makes a normal move. Human
## via the Shuffle button, AI from PhaseCharacterInput.
class_name ShuffleController
extends RefCounted

signal shuffled

var ctx: TurnContext

func _init(p_ctx: TurnContext) -> void:
	ctx = p_ctx

func try_shuffle() -> bool:
	if not ctx.awaiting_player_input or MoveFinder.has_move(ctx.board):
		return false
	perform_shuffle()
	return true

## try_shuffle minus the gates — used by an AI character with no move.
func perform_shuffle() -> void:
	BoardShuffler.shuffle(ctx.board, ctx.board.rng)
	shuffled.emit()
