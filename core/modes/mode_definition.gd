## What the start screen knows about a mode: texts, the settings form, and how
## a chosen setting set becomes a GameMode plus its board. A new mode is one
## subclass registered in ModeCatalog; no UI code changes.
class_name ModeDefinition
extends RefCounted

func id() -> StringName:
	return &""

func title() -> String:
	return "Mode"

## `stats` (may be null) lets a range depend on progress, e.g. Battle's reached level.
func settings_schema(_stats: ModeStats = null) -> Array[SettingSpec]:
	return []

func stat_specs() -> Array[StatSpec]:
	return []

## Difficulty bundles shown above the settings; picking one fills their values. Empty = no preset row.
func presets() -> Array[SettingPreset]:
	return []

func default_preset() -> int:
	return 0

## The `preset` setting holds an index into presets(); presets().size() means Custom.
func default_settings(stats: ModeStats = null) -> Dictionary:
	var settings := {}
	for spec in settings_schema(stats):
		settings[spec.key] = spec.default_value
	var bundles := presets()
	if not bundles.is_empty():
		settings.merge(bundles[default_preset()].values, true)
		settings[&"preset"] = default_preset()
	return settings

## Saved settings laid over the defaults: unknown keys dropped, numbers clamped to today's ranges.
func resolve_settings(saved: Dictionary, stats: ModeStats = null) -> Dictionary:
	var settings := default_settings(stats)
	for key in settings:
		if saved.has(key):
			settings[key] = int(saved[key])
	for spec in settings_schema(stats):
		settings[spec.key] = clampi(settings[spec.key], spec.min_value, spec.max_value)
	if settings.has(&"preset"):
		settings[&"preset"] = clampi(settings[&"preset"], 0, presets().size())
	return settings

func create_mode(_settings: Dictionary) -> GameMode:
	return null

## The mode's `board_params(base, level)` scales down from this.
func world_params(_settings: Dictionary) -> WorldGenParams:
	return WorldGenParams.new()

func start_level(_settings: Dictionary) -> int:
	return 1
