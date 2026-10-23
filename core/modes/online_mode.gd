## PvP between people on different machines, up to 3 a side: seats alternate between the Hero
## team (even seats, the host first) and the Devil team (odd), and every seat but the local one
## is driven by a RemoteController. Everything else is the plain duel (BattleMode), generated
## from the same seed on every client. A match is round after round (each on a new, higher-level
## board): `wins` is the score so far, `departed` the seats whose players left, dead from the start.
class_name OnlineMode
extends BattleMode

var _seat_count: int
var _local_seat: int
var _departed: Array
var _wins: Array

func _init(names: Array, p_local_seat: int, p_departed: Array, p_wins: Array) -> void:
	var heroes: Array[UnitType] = []
	var devils: Array[UnitType] = []
	for seat in names.size():
		var type := UnitType.hero() if seat % 2 == 0 else UnitType.devil()
		type.display_name = names[seat]
		(heroes if seat % 2 == 0 else devils).append(type)
	super("Online", heroes, devils, 0.0, 0.0)
	_seat_count = names.size()
	_local_seat = p_local_seat
	_departed = p_departed
	_wins = p_wins

func build_phases(ctx: TurnContext, level: int) -> Array[TurnPhase]:
	var phases := super(ctx, level)
	for seat in _seat_count:
		if seat != _local_seat:
			seat_character(ctx.battle, seat).controller = RemoteController.new()
	for seat: int in _departed:
		ctx.battle.retire(seat_character(ctx.battle, seat))
	ctx.battle.team_wins = [int(_wins[0]), int(_wins[1])]
	return phases

## Humans go first on their side (EncounterGenerator.build_side), in seat order.
static func seat_character(battle: BattleContext, seat: int) -> Character:
	return (battle.allies if seat % 2 == 0 else battle.enemies)[floori(seat / 2.0)]
