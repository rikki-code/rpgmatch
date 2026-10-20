## State that outlives a scene reload (Restart, next battle).
class_name GameSession
extends RefCounted

static var launch: RunConfig
## GameSnapshot data for GameRoot to restore instead of generating a new game; consumed on read.
static var resume: Dictionary

static var _profile: ProfileData

static func profile() -> ProfileData:
	if _profile == null:
		_profile = SaveStore.load_profile()
	return _profile
