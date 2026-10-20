class_name InfiniteDefinition
extends ModeDefinition

func id() -> StringName:
	return ModeCatalog.INFINITE

func title() -> String:
	return "Infinite Arcade"

func settings_schema(_stats: ModeStats = null) -> Array[SettingSpec]:
	var d := WorldGenParams.new()
	return [
		SettingSpec.new(&"width", "Width", 4, 16, d.width).as_advanced(),
		SettingSpec.new(&"height", "Height", 4, 12, d.height).as_advanced(),
		SettingSpec.new(&"colors", "Tile colors", 3, BoardGraph.MAX_COLORS, d.color_count).as_advanced(),
		SettingSpec.new(&"pits", "Holes", 0, 40, d.pit_count).as_advanced(),
		SettingSpec.new(&"seed", "Seed (0 = random)", 0, 999999999, d.seed_value).as_advanced(),
	]

## The bonus chances (percent) only exist inside presets.
func presets() -> Array[SettingPreset]:
	return [
		_preset("Easy", 6, 7, 4, 0, 5, 0, 0, 0),
		_preset("Normal", 8, 10, 5, 10, 3, 0, 0, 0),
		_preset("Hard", 10, 10, 6, 16, 1, 0, 0, 0),
	]

func default_preset() -> int:
	return 1

func stat_specs() -> Array[StatSpec]:
	return [
		StatSpec.new(ModeStats.BEST_SCORE, "Best score"),
		StatSpec.new(ModeStats.TILES, "Tiles cleared"),
		StatSpec.new(ModeStats.RUNS, "Games played"),
	]

func create_mode(_settings: Dictionary) -> GameMode:
	return InfiniteMode.new()

func world_params(settings: Dictionary) -> WorldGenParams:
	var params := WorldGenParams.new()
	params.width = settings[&"width"]
	params.height = settings[&"height"]
	params.color_count = settings[&"colors"]
	params.pit_count = settings[&"pits"]
	params.color_bomb_spawn_chance = settings[&"color_bombs"] / 100.0
	params.bomb_spawn_chance = settings[&"bombs"] / 100.0
	params.arrow_blaster_spawn_chance = settings[&"arrows"] / 100.0
	params.prisms_spawn_chance = settings[&"prisms"] / 100.0
	params.seed_value = settings[&"seed"]
	return params

func _preset(label: String, width: int, height: int, colors: int, pits: int, color_bombs: int, bombs: int, arrows: int, prisms: int) -> SettingPreset:
	return SettingPreset.new(label, {
		&"width": width,
		&"height": height,
		&"colors": colors,
		&"pits": pits,
		&"color_bombs": color_bombs,
		&"bombs": bombs,
		&"arrows": arrows,
		&"prisms": prisms,
	})
