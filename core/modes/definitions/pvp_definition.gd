## Hot-seat duel: every unit on both sides is a human, no generated filler (budget 0).
class_name PvpDefinition
extends ModeDefinition

func id() -> StringName:
	return ModeCatalog.PVP

func title() -> String:
	return "PvP"

func settings_schema(_stats: ModeStats = null) -> Array[SettingSpec]:
	return [
		SettingSpec.new(&"allies", "Heroes", 1, BattleContext.MAX_PER_SIDE, 1),
		SettingSpec.new(&"enemies", "Devils", 1, BattleContext.MAX_PER_SIDE, 1),
		SettingSpec.new(&"level", "Level (board and stats)", 1, BattleDefinition.MAX_LEVEL, 1),
	]

func stat_specs() -> Array[StatSpec]:
	return [
		StatSpec.new(ModeStats.RUNS, "Matches"),
		StatSpec.new(ModeStats.WINS, "Hero wins"),
		StatSpec.new(ModeStats.LOSSES, "Devil wins"),
	]

func create_mode(settings: Dictionary) -> GameMode:
	return BattleMode.new("PvP", _team(settings[&"allies"], UnitType.hero, "Hero"), _team(settings[&"enemies"], UnitType.devil, "Devil"), 0.0, 0.0)

func start_level(settings: Dictionary) -> int:
	return settings[&"level"]

static func _team(count: int, make: Callable, label: String) -> Array[UnitType]:
	var team: Array[UnitType] = []
	for i in range(count):
		var type: UnitType = make.call()
		if count > 1:
			type.display_name = "%s %d" % [label, i + 1]
		team.append(type)
	return team
