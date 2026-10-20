## The only place that touches saved files (user:// is IndexedDB on the web).
class_name SaveStore
extends RefCounted

const PROFILE_PATH := "user://profile.json"

static func load_profile() -> ProfileData:
	if not FileAccess.file_exists(PROFILE_PATH):
		return ProfileData.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not (data is Dictionary):
		push_warning("Unreadable profile, starting a fresh one")
		return ProfileData.new()
	return ProfileData.from_dict(data)

static func save_profile(profile: ProfileData) -> bool:
	return _write(PROFILE_PATH, JSON.stringify(profile.to_dict()))

static func load_run(mode_id: StringName) -> RunSave:
	var path := _run_path(mode_id)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var run: RunSave = RunSave.from_dict(data) if data is Dictionary else null
	if run == null:
		push_warning("Unreadable run save for %s, ignoring it" % mode_id)
	return run

static func save_run(run: RunSave) -> bool:
	return _write(_run_path(run.config.mode_id), JSON.stringify(run.to_dict()))

static func delete_run(mode_id: StringName) -> void:
	var path := _run_path(mode_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func _run_path(mode_id: StringName) -> String:
	return "user://run_%s.json" % mode_id

## Writes beside the target and renames, so an interrupted write never leaves a half file.
static func _write(path: String, text: String) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write %s (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	var error := DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_warning("Cannot replace %s (error %d)" % [path, error])
	return error == OK
