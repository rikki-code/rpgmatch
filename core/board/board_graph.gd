## The field is a graph of cells, not a fixed 2D array: adjacency lives on
## each GridCell as explicit neighbor links, so later mechanics (portals,
## rotating segments, conveyors) can rewire links without touching the
## algorithms that only ever walk `neighbors`.
class_name BoardGraph
extends RefCounted

var width: int
var height: int
## Tile color ids exist 0..MAX_COLORS-1 (one per tile scene in the view).
const MAX_COLORS := 6

## Which color ids this board plays with — a random subset per generation.
var colors: Array[int] = [0, 1, 2, 3, 4]
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

## The full board for a save. rng state goes out as strings: JSON numbers lose 64-bit precision.
func to_dict() -> Dictionary:
	var cell_list := []
	for cell: GridCell in all_cells():
		cell_list.append({
			"x": cell.position.x,
			"y": cell.position.y,
			"kind": String(cell.kind.id()),
			"tile": EntityCodec.encode(cell.occupant),
		})
	return {
		"width": width,
		"height": height,
		"colors": colors,
		"chances": {
			"prisms": prisms_spawn_chance,
			"arrow_blaster": arrow_blaster_spawn_chance,
			"bomb": bomb_spawn_chance,
			"color_bomb": color_bomb_spawn_chance,
		},
		"rng": {"seed": str(rng.seed), "state": str(rng.state)},
		"cells": cell_list,
	}

static func from_dict(data: Dictionary) -> BoardGraph:
	var graph := BoardGraph.new(int(data["width"]), int(data["height"]))
	graph.colors.clear()
	for color in data["colors"]:
		graph.colors.append(int(color))
	var chances: Dictionary = data["chances"]
	graph.prisms_spawn_chance = float(chances["prisms"])
	graph.arrow_blaster_spawn_chance = float(chances["arrow_blaster"])
	graph.bomb_spawn_chance = float(chances["bomb"])
	graph.color_bomb_spawn_chance = float(chances["color_bomb"])
	graph.restore_rng(data["rng"])
	for entry: Dictionary in data["cells"]:
		var cell := GridCell.new(Vector2i(int(entry["x"]), int(entry["y"])), CellKindCodec.decode(StringName(entry["kind"])))
		cell.occupant = EntityCodec.decode(entry["tile"])
		graph.add_cell(cell)
	graph.link_grid_neighbors()
	return graph

func restore_rng(data: Dictionary) -> void:
	rng.seed = int(data["seed"])
	rng.state = int(data["state"])

func random_color() -> int:
	return colors[rng.randi_range(0, colors.size() - 1)]

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
