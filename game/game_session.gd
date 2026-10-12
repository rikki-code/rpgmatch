## Settings that outlive a scene reload (Reset / mode change / new board size).
class_name GameSession
extends RefCounted

static var params: WorldGenParams
## Index into GameRoot.available_modes; 1 = Battle (the default for now).
static var mode_index := 1
## Battle progression; +1 per victory, kept across the reloads between battles.
static var battle_level := 1
