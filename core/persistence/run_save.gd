## One Continue slot: the run's config plus its GameSnapshot. Plain data (SaveStore does the file access).
class_name RunSave
extends RefCounted

## A new version adds a migration step in from_dict; unknown versions are dropped, never half-read.
const VERSION := 1

var config: RunConfig
var game: Dictionary

func _init(p_config: RunConfig, p_game: Dictionary) -> void:
	config = p_config
	game = p_game

func to_dict() -> Dictionary:
	return {"version": VERSION, "mode": config.mode_id, "settings": config.settings, "level": config.level, "game": game}

static func from_dict(data: Dictionary) -> RunSave:
	if int(data.get("version", 0)) != VERSION or not data.has_all(["mode", "settings", "level", "game"]):
		return null
	var definition := ModeCatalog.find(StringName(data["mode"]))
	var snapshot: Variant = data["game"]
	if definition == null or not (snapshot is Dictionary) or not snapshot.has_all(["board", "score", "quests"]):
		return null
	var run_config := RunConfig.new(definition, definition.resolve_settings(data["settings"]))
	run_config.level = int(data["level"])
	if run_config.create_mode().shows_battle_view() != snapshot.has("battle"):
		return null
	return RunSave.new(run_config, snapshot)
