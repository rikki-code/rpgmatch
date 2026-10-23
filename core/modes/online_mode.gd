## PvP against a person on another machine: the host plays the Hero, the guest the
## Devil, and the other side's character is driven by a RemoteController. Everything
## else is the plain duel (BattleMode), generated from the same seed on both clients.
class_name OnlineMode
extends BattleMode

var _local_is_host: bool

func _init(host_name: String, guest_name: String, p_local_is_host: bool) -> void:
	var hero := UnitType.hero()
	hero.display_name = host_name
	var devil := UnitType.devil()
	devil.display_name = guest_name
	super("Online", [hero], [devil], 0.0, 0.0)
	_local_is_host = p_local_is_host

func build_phases(ctx: TurnContext, level: int) -> Array[TurnPhase]:
	var phases := super(ctx, level)
	# Humans go first on their side (EncounterGenerator.build_side).
	var remote := ctx.battle.enemies[0] if _local_is_host else ctx.battle.allies[0]
	remote.controller = RemoteController.new()
	return phases
