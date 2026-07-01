## Serializable hand-authored layout, saved/loaded as a .tres via
## ResourceSaver/ResourceLoader. Produces the same BoardGraph shape as
## BoardGenerator, so downstream code never needs to know which one built
## the board it's holding.
class_name BoardLayout
extends Resource

@export var width: int = 0
@export var height: int = 0
@export var pit_positions: Array[Vector2i] = []
@export var fixed_tile_colors: Dictionary = {}  # Vector2i -> int

static func from_graph(graph: BoardGraph) -> BoardLayout:
	var layout := BoardLayout.new()
	layout.width = graph.width
	layout.height = graph.height
	for cell: GridCell in graph.all_cells():
		if cell.kind is PitCellKind:
			layout.pit_positions.append(cell.position)
		if cell.occupant is Tile:
			var tile: Tile = cell.occupant
			layout.fixed_tile_colors[cell.position] = tile.color
	return layout

func build_graph() -> BoardGraph:
	var graph := BoardGraph.new(width, height)
	for y in range(height):
		for x in range(width):
			graph.add_cell(GridCell.new(Vector2i(x, y), NormalCellKind.new()))
	graph.link_grid_neighbors()

	for pos in pit_positions:
		var cell := graph.get_cell(pos)
		if cell != null:
			cell.kind = PitCellKind.new()

	for pos in fixed_tile_colors.keys():
		var cell := graph.get_cell(pos)
		if cell != null:
			cell.occupant = Tile.make_normal(fixed_tile_colors[pos])

	return graph
