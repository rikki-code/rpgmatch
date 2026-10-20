## Packs the player can choose between, and the saved choice (user://packs.cfg).
## Knows nothing about the pack consumers (PackPaths reads it during static init,
## so a reference back would be a cycle); GameRoot reloads them after apply().
class_name PackCatalog
extends RefCounted

const CONFIG_PATH := "user://packs.cfg"
const TILES := &"tiles"
const BOARD := &"board"
const AUDIO := &"audio"

const OPTIONS := {
	TILES: [
		{"id": "crystal", "name": "Crystals", "path": "res://view/packs/tiles_pack/crystal_pack/"},
		{"id": "six_seven", "name": "Six Seven", "path": "res://view/packs/tiles_pack/six_seven_pack/"},
	],
	BOARD: [
		{"id": "dungeon", "name": "Dungeon", "path": "res://view/packs/board_pack/dungeon_pack/"},
		{"id": "earth", "name": "Meadow", "path": "res://view/packs/board_pack/earth_pack/"},
	],
	AUDIO: [
		{"id": "dungeon", "name": "Dungeon", "path": "res://view/packs/audio_pack/dungeon_pack/"},
		{"id": "crystal", "name": "Chimes", "path": "res://view/packs/audio_pack/crystal_pack/"},
	],
}

static var _chosen: Dictionary = {}  # category -> id

static func options(category: StringName) -> Array:
	return OPTIONS[category]

static func selected_id(category: StringName) -> String:
	if _chosen.is_empty():
		_load()
	return _chosen.get(category, OPTIONS[category][0]["id"])

static func selected_path(category: StringName) -> String:
	var id := selected_id(category)
	for option: Dictionary in OPTIONS[category]:
		if option["id"] == id:
			return option["path"]
	return OPTIONS[category][0]["path"]

# `selection` maps category -> option id.
static func apply(selection: Dictionary) -> void:
	for category: StringName in selection:
		_chosen[category] = selection[category]
	_save()

static func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		for category: StringName in OPTIONS:
			_chosen[category] = config.get_value("packs", category, OPTIONS[category][0]["id"])
	else:
		for category: StringName in OPTIONS:
			_chosen[category] = OPTIONS[category][0]["id"]

static func _save() -> void:
	var config := ConfigFile.new()
	for category: StringName in _chosen:
		config.set_value("packs", category, _chosen[category])
	config.save(CONFIG_PATH)
