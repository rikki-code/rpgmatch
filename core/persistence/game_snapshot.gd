## What a Continue restores, taken at a turn-cycle boundary: the board is settled and no action is pending.
class_name GameSnapshot
extends RefCounted

static func capture(ctx: TurnContext, quests: QuestManager) -> Dictionary:
	var data := {
		"board": ctx.board.to_dict(),
		"score": ctx.score_tracker.to_dict(),
		"quests": quests.to_dict(),
	}
	if ctx.battle != null:
		data["battle"] = ctx.battle.to_dict()
	return data
