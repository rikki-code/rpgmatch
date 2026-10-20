## One chosen way to play: which mode, its settings, and the progression level
## inside the run (Battle: +1 per victory). Everything a scene reload needs to
## rebuild the same game.
class_name RunConfig
extends RefCounted

var mode_id: StringName
var settings: Dictionary
var level: int

func _init(p_definition: ModeDefinition, p_settings := {}) -> void:
	mode_id = p_definition.id()
	settings = p_definition.default_settings()
	settings.merge(p_settings, true)
	level = p_definition.start_level(settings)

static func defaults(p_definition: ModeDefinition) -> RunConfig:
	return RunConfig.new(p_definition)

func definition() -> ModeDefinition:
	return ModeCatalog.find(mode_id)

func create_mode() -> GameMode:
	return definition().create_mode(settings)

func world_params() -> WorldGenParams:
	return definition().world_params(settings)
