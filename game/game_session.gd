## State that outlives a scene reload (Restart, next battle).
class_name GameSession
extends RefCounted

static var launch: RunConfig
## GameSnapshot data for GameRoot to restore instead of generating a new game; consumed on read.
static var resume: Dictionary
## An online match goes on in the next round: the reload must not leave it.
static var online_next_round := false

static var _profile: ProfileData

static func profile() -> ProfileData:
	if _profile == null:
		_profile = SaveStore.load_profile()
	return _profile
