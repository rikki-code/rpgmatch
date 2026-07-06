## Builds a random BoardGraph from WorldGenParams. Steps are independent and
## run in sequence (grid -> pits -> tiles) so a new generation knob only
## touches the step it belongs to. See
## .claude/skills/match3-worldgen/SKILL.md for how to extend this.
class_name BoardGenerator
extends RefCounted

static func generate(params: WorldGenParams) -> BoardGraph:
	var rng := RandomNumberGenerator.new()
	if params.seed_value != 0:
		rng.seed = params.seed_value
	else:
		rng.randomize()

	var graph := BoardGraph.new(params.width, params.height)
	graph.color_count = params.color_count
	graph.arrow_blaster_spawn_chance = params.arrow_blaster_spawn_chance
	graph.bomb_spawn_chance = params.bomb_spawn_chance
	graph.color_bomb_spawn_chance = params.color_bomb_spawn_chance
	graph.prisms_spawn_chance = params.prisms_spawn_chance
	graph.rng = rng

	for y in range(params.height):
		for x in range(params.width):
			graph.add_cell(GridCell.new(Vector2i(x, y), NormalCellKind.new()))
	graph.link_grid_neighbors()

	_place_pits(graph, params, rng)
	_spawn_tiles(graph, rng)
	return graph

static func _place_pits(graph: BoardGraph, params: WorldGenParams, rng: RandomNumberGenerator) -> void:
	var pit_count: int = clampi(params.pit_count, 0, graph.cells.size())
	var candidates: Array = _shuffled(graph.all_cells(), rng)
	for i in range(pit_count):
		var cell: GridCell = candidates[i]
		cell.kind = PitCellKind.new()

static func _spawn_tiles(graph: BoardGraph, rng: RandomNumberGenerator) -> void:
	for y in range(graph.height):
		for x in range(graph.width):
			var cell := graph.get_cell(Vector2i(x, y))
			if cell == null or not cell.kind.can_hold_tile():
				continue
			var forbidden := _colors_that_would_match(cell)
			cell.occupant = _make_tile(_pick_color(graph.color_count, forbidden, rng))

## Avoids a pre-made match ≥3 at generation time by forbidding the color of
## any already-placed pair directly above or to the left.
static func _colors_that_would_match(cell: GridCell) -> Array[int]:
	var forbidden: Array[int] = []
	var left1 := cell.neighbor(GridDirection.Dir.LEFT)
	var left2: GridCell = left1.neighbor(GridDirection.Dir.LEFT) if left1 != null else null
	if left1 != null and left2 != null and left1.occupant is Tile and left2.occupant is Tile:
		var a: Tile = left1.occupant
		var b: Tile = left2.occupant
		if a.color == b.color:
			forbidden.append(a.color)

	var up1 := cell.neighbor(GridDirection.Dir.UP)
	var up2: GridCell = up1.neighbor(GridDirection.Dir.UP) if up1 != null else null
	if up1 != null and up2 != null and up1.occupant is Tile and up2.occupant is Tile:
		var c: Tile = up1.occupant
		var d: Tile = up2.occupant
		if c.color == d.color:
			forbidden.append(c.color)

	return forbidden

static func _pick_color(color_count: int, forbidden: Array[int], rng: RandomNumberGenerator) -> int:
	var color := rng.randi_range(0, color_count - 1)
	var attempts := 0
	while forbidden.has(color) and attempts < 20:
		color = rng.randi_range(0, color_count - 1)
		attempts += 1
	return color

static func _make_tile(color: int) -> Tile:
	return Tile.make_normal(color)

static func _shuffled(array: Array, rng: RandomNumberGenerator) -> Array:
	var result := array.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result
