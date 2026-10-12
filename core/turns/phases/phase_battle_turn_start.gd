## Picks whose turn it is (initiative order, new round when the queue runs
## dry) and resets the turn's points/combo. Once a side is wiped it halts
## the turn loop for good — TurnManager simply stops advancing.
class_name PhaseBattleTurnStart
extends TurnPhase

var _halted := false

func is_instant() -> bool:
	return not _halted

func execute(ctx: TurnContext) -> void:
	var battle := ctx.battle
	ctx.awaiting_player_input = false
	if battle.is_battle_over():
		_halted = true
		battle.finish()
		return
	var actor := battle.queue.next_actor()
	if actor == null:
		battle.queue.start_round(battle.all_characters())
		actor = battle.queue.next_actor()
	ctx.board.swapped_tiles = []
	ctx.score_tracker.reset_combo()
	battle.begin_turn(actor)
