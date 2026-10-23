## The opponent of an online match: its turn is whatever the other client sent
## (see OnlineSync). Both clients run the same deterministic game, so a turn is
## replayed from a handful of messages: the picked action and target, and the board move.
class_name RemoteController
extends CharacterController

## The replay cannot match the other client's game anymore.
signal desynced
signal _arrived

var _inbox: Array[Dictionary] = []

func is_player() -> bool:
	return true

func is_remote() -> bool:
	return true

func to_dict() -> Dictionary:
	return {"type": "remote"}

## `{"t": "bye"}` (the player left: its character goes at its next turn), `{"t": "shuffle"}` or `{"t": "move", "kind": "swap"|"detonate", "a": [x, y], "b": [x, y],
## "action": index, "target": index}`; each carries "rng", the board rng state at the turn's start.
func push(message: Dictionary) -> void:
	_inbox.append(message)
	_arrived.emit()

## What arrived but was not played: it belongs to the next round.
func drain() -> Array[Dictionary]:
	var rest := _inbox.duplicate()
	_inbox.clear()
	return rest

func take_turn(ctx: TurnContext) -> void:
	var battle := ctx.battle
	var turn_rng := str(ctx.board.rng.state)
	while true:
		while _inbox.is_empty():
			await _arrived
		var message: Dictionary = _inbox.pop_front()
		if message.get("t") == "bye":
			battle.retire(battle.active_character)
			ctx.turn_manager.notify_phase_done()
			return
		if str(message.get("rng", "")) != turn_rng:
			desynced.emit()
			return
		if message.get("t") == "shuffle":
			ctx.shuffle_controller.perform_shuffle()
			continue
		var is_swap: bool = message.get("kind") == "swap"
		var cell_a := _cell(ctx, message.get("a"))
		var cell_b := _cell(ctx, message.get("b")) if is_swap else null
		var action: Variant = _at(battle.actions, message.get("action"))
		var target: Variant = _at(battle.all_characters(), message.get("target"))
		var valid_kind: bool = is_swap or message.get("kind") == "detonate"
		if not valid_kind or cell_a == null or action == null or target == null or (is_swap and cell_b == null):
			desynced.emit()
			return
		battle.select_action(action)
		battle.select_target(target)
		battle.ai_move_chosen.emit(cell_a, cell_b)
		await ctx.animation_driver.await_delay(AI_PREVIEW_SECONDS)
		var done: bool
		if cell_b == null:
			done = await ctx.detonate_controller.perform_detonate(cell_a)
		else:
			done = await ctx.swap_controller.perform_swap(cell_a, cell_b)
		if not done:
			desynced.emit()
		return

## Anything from the network may be malformed: null when it is not a valid cell.
static func _cell(ctx: TurnContext, coords: Variant) -> GridCell:
	if not (coords is Array) or coords.size() != 2:
		return null
	return ctx.board.get_cell(Vector2i(int(coords[0]), int(coords[1])))

static func _at(items: Array, index: Variant) -> Variant:
	if not (index is float or index is int) or int(index) < 0 or int(index) >= items.size():
		return null
	return items[int(index)]
