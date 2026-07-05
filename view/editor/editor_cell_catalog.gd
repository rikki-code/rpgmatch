## Registry of cell kinds placeable by the world editor's cell dropdown. A
## new CellKind (sand cover, impassable, portal floor...) is one new Entry
## here — no other editor file needs to change.
class_name EditorCellCatalog
extends RefCounted

class Entry:
	var id: StringName
	var display_name: String
	var factory: Callable

	func _init(p_id: StringName, p_display_name: String, p_factory: Callable) -> void:
		id = p_id
		display_name = p_display_name
		factory = p_factory

static func build() -> Array[Entry]:
	var entries: Array[Entry] = []
	entries.append(Entry.new(&"normal", "Normal", func() -> CellKind: return NormalCellKind.new()))
	entries.append(Entry.new(&"pit", "Pit", func() -> CellKind: return PitCellKind.new()))
	return entries
