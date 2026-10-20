## Cell kind <-> its saved id. A new CellKind adds one line here.
class_name CellKindCodec
extends RefCounted

static func decode(id: StringName) -> CellKind:
	match id:
		&"normal":
			return NormalCellKind.new()
		&"pit":
			return PitCellKind.new()
	push_error("Unknown cell kind: %s" % id)
	return NormalCellKind.new()
