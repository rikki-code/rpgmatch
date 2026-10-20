class_name BattleDefinition
extends ModeDefinition

const MAX_LEVEL := 99

func id() -> StringName:
	return ModeCatalog.BATTLE

func title() -> String:
	return "Battle"

## You can start at any level you have already reached, by default the highest.
func settings_schema(stats: ModeStats = null) -> Array[SettingSpec]:
	var reached := MAX_LEVEL if stats == null else maxi(stats.value_of(ModeStats.BEST_LEVEL), 1)
	return [SettingSpec.new(&"level", "Start level", 1, reached, 1 if stats == null else reached)]

func stat_specs() -> Array[StatSpec]:
	return [
		StatSpec.new(ModeStats.BEST_LEVEL, "Best level"),
		StatSpec.new(ModeStats.WINS, "Battles won"),
		StatSpec.new(ModeStats.LOSSES, "Battles lost"),
		StatSpec.new(ModeStats.TILES, "Tiles cleared"),
	]

func create_mode(_settings: Dictionary) -> GameMode:
	return BattleMode.new("Battle", [UnitType.hero()], [], 0.92, 1.0)

func start_level(settings: Dictionary) -> int:
	return settings[&"level"]
