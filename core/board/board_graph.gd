## The field is a graph of cells, not a fixed 2D array: adjacency lives on
## each GridCell as explicit neighbor links, so later mechanics (portals,
## rotating segments, conveyors) can rewire links without touching the
## algorithms that only ever walk `neighbors`.
class_name BoardGraph
extends RefCounted

var width: int
var height: int
var color_count: int = 5
var prisms_spawn_chance: float = 0.0
var arrow_blaster_spawn_chance: float = 0.0
var bomb_spawn_chance: float = 0.0
var color_bomb_spawn_chance: float = 0.0
var swapped_tiles: Array[Tile] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var cells: Dictionary = {}  # Vector2i -> GridCell

func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height

func add_cell(cell: GridCell) -> void:
	cells[cell.position] = cell

func get_cell(pos: Vector2i) -> GridCell:
	return cells.get(pos)

func all_cells() -> Array:
	return cells.values()

## Wires the default rectangular 4-neighbor grid. Call again (or rewrite
## individual `GridCell.neighbors` entries) to build non-rectangular or
## dynamically reconnected topologies later. Unconditional assignment (even
## to null) matters once cells can be removed at runtime (see remove_cell) —
## otherwise a neighbor's link to a just-removed cell would stay dangling.
func link_grid_neighbors() -> void:
	for cell: GridCell in cells.values():
		for dir in GridDirection.ALL:
			var offset: Vector2i = GridDirection.OFFSETS[dir]
			cell.neighbors[dir] = get_cell(cell.position + offset)

## Removes a cell entirely — a true gap in the graph, same as the board's
## own edge, not a pit (see PitCellKind). Takes its occupant with it; re-add
## via add_cell() to restore. Relinks so neighbors pointing here clear their
## stale reference instead of walking into a freed GridCell.
func remove_cell(pos: Vector2i) -> void:
	cells.erase(pos)
	link_grid_neighbors()

## Top-to-bottom, keeping a `null` entry for any (x, y) with no cell at all
## (the board doesn't have to be rectangular) — gravity treats a gap the
## same as a pit: a barrier, not something to silently skip over.
func column_cells_top_to_bottom(x: int) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for y in range(height):
		result.append(get_cell(Vector2i(x, y)))
	return result

func swap_occupants(a: GridCell, b: GridCell) -> void:
	var tmp := a.occupant
	a.occupant = b.occupant
	b.occupant = tmp

func has_empty_holdable_cell() -> bool:
	for cell: GridCell in all_cells():
		if cell.occupant == null and cell.kind.can_hold_tile():
			return true
	return false

func cells_within_manhattan_radius(origin: GridCell, radius: int, include_origin: bool = false) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if absi(dx) + absi(dy) > radius:
				continue
			if dx == 0 and dy == 0 and not include_origin:
				continue
			var target := get_cell(origin.position + Vector2i(dx, dy))
			if target != null:
				result.append(target)
	return result

func cells_within_square_radius(origin: GridCell, radius: int, include_origin: bool = false) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0 and not include_origin:
				continue
			var target := get_cell(origin.position + Vector2i(dx, dy))
			if target != null:
				result.append(target)
	return result

func cells_within_row_band(origin: GridCell, extra_rows: int) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dy in range(-extra_rows, extra_rows + 1):
		var y := origin.position.y + dy
		for x in range(width):
			var target := get_cell(Vector2i(x, y))
			if target != null:
				result.append(target)
	return result

func cells_within_column_band(origin: GridCell, extra_columns: int) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dx in range(-extra_columns, extra_columns + 1):
		var x := origin.position.x + dx
		for y in range(height):
			var target := get_cell(Vector2i(x, y))
			if target != null:
				result.append(target)
	return result
