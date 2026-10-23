## Keeps the two clients of an online match in step. Both run the same deterministic game
## from the same seed, so only the player's choices travel: when the local human makes a
## board move it is sent to the opponent, and what the opponent sent is handed to its
## RemoteController, which replays it as that character's turn. The transport (Net) is
## plugged in by GameRoot: `outgoing` out, receive() / opponent_left() in.
class_name OnlineSync
extends RefCounted

## The match cannot go on: the opponent left, or the two games stopped agreeing.
signal match_lost(reason: String)
signal outgoing(message: Dictionary)

var _ctx: TurnContext
var _remote: RemoteController
## Board rng state when the current turn began: identical on both clients unless they diverged.
var _turn_rng := ""

func setup(ctx: TurnContext) -> void:
	_ctx = ctx
	for character in ctx.battle.all_characters():
		if character.controller.is_remote():
			_remote = character.controller
	ctx.battle.turn_started.connect(_on_turn_started)
	ctx.swap_controller.swap_applied.connect(_on_swap)
	ctx.swap_controller.tiles_combined.connect(_on_swap)
	ctx.detonate_controller.detonated.connect(_on_detonated)
	ctx.shuffle_controller.shuffled.connect(_on_shuffled)
	_remote.desynced.connect(_on_desynced)

## A message of the opponent.
func receive(message: Dictionary) -> void:
	_remote.push(message)

func opponent_left(reason: String) -> void:
	_lose(reason)

func _on_turn_started(_character: Character) -> void:
	_turn_rng = str(_ctx.board.rng.state)

## Moves the remote character makes go through the same controllers; only the local human's are sent.
func _is_local_turn() -> bool:
	var actor := _ctx.battle.active_character
	return actor != null and actor.controller.is_human() and not _ctx.battle.ended

func _on_swap(cell_a: GridCell, cell_b: GridCell) -> void:
	if _is_local_turn():
		outgoing.emit(_move("swap", cell_a, cell_b))

func _on_detonated(cell: GridCell) -> void:
	if _is_local_turn():
		outgoing.emit(_move("detonate", cell, null))

func _on_shuffled() -> void:
	if _is_local_turn():
		outgoing.emit({"t": "shuffle", "rng": _turn_rng})

func _move(kind: String, cell_a: GridCell, cell_b: GridCell) -> Dictionary:
	var battle := _ctx.battle
	var message := {
		"t": "move",
		"kind": kind,
		"a": [cell_a.position.x, cell_a.position.y],
		"action": battle.actions.find(battle.pending_action),
		"target": battle.all_characters().find(battle.pending_target),
		"rng": _turn_rng,
	}
	if cell_b != null:
		message["b"] = [cell_b.position.x, cell_b.position.y]
	return message

func _on_desynced() -> void:
	_lose("The two games got out of sync")

## Nothing to report once the battle is decided: the result screen is already up.
func _lose(reason: String) -> void:
	if not _ctx.battle.ended:
		match_lost.emit(reason)
