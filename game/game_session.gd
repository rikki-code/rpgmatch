## Settings that outlive a scene reload (Reset / mode change / new board size).
class_name GameSession
extends RefCounted

static var params: WorldGenParams
## Index into GameRoot.available_modes; 1 = Battle (the default for now).
static var mode_index := 1
