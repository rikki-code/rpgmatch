## Everything saved about the player across games: per-mode stats and the last
## settings used in each mode's setup form. Plain data, no file access (SaveStore does that).
class_name ProfileData
extends RefCounted

const VERSION := 1
const DEFAULT_PLAYER_NAME := "Player"

var _stats: Dictionary = {}  # StringName -> ModeStats
var _settings: Dictionary = {}  # StringName -> Dictionary
## Shown to the opponent in online matches.
var player_name := DEFAULT_PLAYER_NAME

func stats_for(mode_id: StringName) -> ModeStats:
	if not _stats.has(mode_id):
		_stats[mode_id] = ModeStats.new()
	return _stats[mode_id]

func settings_for(mode_id: StringName) -> Dictionary:
	return _settings.get(mode_id, {})

func remember_settings(mode_id: StringName, settings: Dictionary) -> void:
	_settings[mode_id] = settings.duplicate()

func to_dict() -> Dictionary:
	var stats := {}
	for mode_id: StringName in _stats:
		stats[mode_id] = _stats[mode_id].to_dict()
	return {"version": VERSION, "stats": stats, "settings": _settings, "player_name": player_name}

static func from_dict(data: Dictionary) -> ProfileData:
	var profile := ProfileData.new()
	profile.player_name = str(data.get("player_name", "")).strip_edges()
	if profile.player_name == "":
		profile.player_name = DEFAULT_PLAYER_NAME
	var stats: Dictionary = data.get("stats", {})
	for mode_id in stats:
		profile._stats[StringName(mode_id)] = ModeStats.from_dict(stats[mode_id])
	var settings: Dictionary = data.get("settings", {})
	for mode_id in settings:
		var saved := {}
		for key in settings[mode_id]:
			saved[StringName(key)] = int(settings[mode_id][key])
		profile._settings[StringName(mode_id)] = saved
	return profile
