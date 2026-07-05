## Registry of tile recipes placeable by the world editor's tile dropdowns.
## A new placeable tile (bonus, penalty, whatever comes next) is one new
## Entry here — no other editor file needs to change.
class_name EditorTileCatalog
extends RefCounted

enum Category { NORMAL, SPECIAL }

class Entry:
	var id: StringName
	var category: Category
	var display_name: String
	## Invalid Callable marks the "erase" entry: clears whatever tile occupies the cell.
	var factory: Callable

	func _init(p_id: StringName, p_category: Category, p_display_name: String, p_factory: Callable) -> void:
		id = p_id
		category = p_category
		display_name = p_display_name
		factory = p_factory

## Reads board.color_count so the normal-tile list matches whatever this
## board was generated with, instead of a hardcoded color count.
static func build(board: BoardGraph) -> Array[Entry]:
	var entries: Array[Entry] = []
	entries.append(Entry.new(&"erase", Category.NORMAL, "Erase", Callable()))
	for color in range(board.color_count):
		entries.append(Entry.new(&"normal_%d" % color, Category.NORMAL, "Color %d" % color, func() -> Tile: return Tile.make_normal(color)))

	entries.append(Entry.new(&"arrow_row", Category.SPECIAL, "Arrow (Row)", func() -> Tile: return Tile.make_arrow_blaster(ArrowBlasterCore.Axis.ROW)))
	entries.append(Entry.new(&"arrow_col", Category.SPECIAL, "Arrow (Column)", func() -> Tile: return Tile.make_arrow_blaster(ArrowBlasterCore.Axis.COLUMN)))
	entries.append(Entry.new(&"bomb", Category.SPECIAL, "Bomb", func() -> Tile: return Tile.make_bomb()))
	for color in range(board.color_count):
		entries.append(Entry.new(&"normal_%d" % color, Category.SPECIAL, "Bomb %d" % color, func() -> Tile: return Tile.make_color_bomb(color)))
	return entries
