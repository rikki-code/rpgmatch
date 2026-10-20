## Every mode the start screen offers, in display order.
class_name ModeCatalog
extends RefCounted

const INFINITE := &"infinite"
const BATTLE := &"battle"
const PVP := &"pvp"

static var _all: Array[ModeDefinition] = [
	InfiniteDefinition.new(),
	BattleDefinition.new(),
	PvpDefinition.new(),
]

static func all() -> Array[ModeDefinition]:
	return _all

static func find(id: StringName) -> ModeDefinition:
	for definition in _all:
		if definition.id() == id:
			return definition
	return null
