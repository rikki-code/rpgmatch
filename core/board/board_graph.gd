## The field is a graph of cells, not a fixed 2D array: adjacency lives on
## each GridCell as explicit neighbor links, so later mechanics (portals,
## rotating segments, conveyors) can rewire links without touching the
## algorithms that only ever walk `neighbors`.
class_name BoardGraph
extends RefCounted

var width: int
var height: int
var color_count: int = 5
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
## dynamically reconnected topologies later.
func link_grid_neighbors() -> void:
	for cell: GridCell in cells.values():
		for dir in GridDirection.ALL:
			var offset: Vector2i = GridDirection.OFFSETS[dir]
			var neighbor_cell := get_cell(cell.position + offset)
			if neighbor_cell != null:
				cell.neighbors[dir] = neighbor_cell

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
