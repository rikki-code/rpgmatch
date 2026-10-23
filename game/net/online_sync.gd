## Keeps the clients of an online match in step. All of them run the same deterministic game
## from the same seed, so only the players' choices travel: when the local human makes a
## board move it is sent to the others, and what another player sent is handed to the
## RemoteController of that seat, which replays it as that character's turn. The transport
## (Net) is plugged in by GameRoot: `outgoing` out, receive() / connection_lost() in.
class_name OnlineSync
extends RefCounted

## The match cannot go on: our link is down, or the games stopped agreeing.
signal match_lost(reason: String)
signal outgoing(message: Dictionary)

var _ctx: TurnContext
var _remotes := {}  # seat -> RemoteController
var _seat_count := 0
## Seats whose players left, in the game's own order (see RemoteController's bye).
var _departed: Array[int] = []
## Board rng state when the current turn began: identical on all clients unless they diverged.
var _turn_rng := ""

func setup(ctx: TurnContext, local_seat: int, departed: Array) -> void:
	_ctx = ctx
	_seat_count = ctx.battle.all_characters().size()
	for seat: int in departed:
		_departed.append(seat)
	ctx.battle.character_left.connect(_on_character_left)
	for seat in _seat_count:
		if seat != local_seat:
			var remote: RemoteController = OnlineMode.seat_character(ctx.battle, seat).controller
			remote.desynced.connect(_on_desynced)
			_remotes[seat] = remote
	ctx.battle.turn_started.connect(_on_turn_started)
	ctx.swap_controller.swap_applied.connect(_on_swap)
	ctx.swap_controller.tiles_combined.connect(_on_swap)
	ctx.detonate_controller.detonated.connect(_on_detonated)
	ctx.shuffle_controller.shuffled.connect(_on_shuffled)

## A message of another player ("s" = its seat, set by Net); `bye` = it left.
func receive(message: Dictionary) -> void:
	var remote: RemoteController = _remotes.get(int(message.get("s", -1)))
	if remote != null:
		remote.push(message)

## Another round can only be played if both teams still have somebody in it.
func can_continue() -> bool:
	for team in 2:
		var alive := false
		for seat in range(team, _seat_count, 2):
			alive = alive or not _departed.has(seat)
		if not alive:
			return false
	return true

func departed_seats() -> Array[int]:
	return _departed

## Everything received for the round that is over, to be played in the next one.
func unplayed_messages() -> Array[Dictionary]:
	var rest: Array[Dictionary] = []
	for remote: RemoteController in _remotes.values():
		rest.append_array(remote.drain())
	return rest

func connection_lost(reason: String) -> void:
	_lose(reason)

func _on_character_left(character: Character) -> void:
	for seat in _seat_count:
		if OnlineMode.seat_character(_ctx.battle, seat) == character and not _departed.has(seat):
			_departed.append(seat)

func _on_turn_started(_character: Character) -> void:
	_turn_rng = str(_ctx.board.rng.state)

## Moves the remote characters make go through the same controllers; only the local human's are sent.
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
	_lose("The games got out of sync")

func _lose(reason: String) -> void:
	match_lost.emit(reason)
