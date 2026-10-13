## Reshuffles the tiles already on the board (same tiles, new cells) until
## there's no ready-made match and at least one legal move. A shuffle never
## resolves anything itself, so it scores nothing for anyone.
class_name BoardShuffler
extends RefCounted

const MAX_ATTEMPTS := 100

static func shuffle(board: BoardGraph, rng: RandomNumberGenerator) -> void:
	var cells: Array[GridCell] = []
	for cell: GridCell in board.all_cells():
		if cell.occupant is Tile and not (cell.occupant as Tile).blocks_swap():
			cells.append(cell)
	var tiles: Array = cells.map(func(c: GridCell) -> Tile: return c.occupant)
	for attempt in range(MAX_ATTEMPTS):
		_shuffle_in_place(tiles, rng)
		for i in range(cells.size()):
			cells[i].occupant = tiles[i]
		if MatchFinder.find_matches(board).is_empty() and MoveFinder.has_move(board):
			return
	# Tile set can't be arranged match-free with a move: recolor plain tiles.
	for attempt in range(MAX_ATTEMPTS):
		_recolor_plain_tiles(board, rng)
		if MoveFinder.has_move(board):
			return

static func _shuffle_in_place(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp

static func _recolor_plain_tiles(board: BoardGraph, rng: RandomNumberGenerator) -> void:
	for y in range(board.height):
		for x in range(board.width):
			var cell := board.get_cell(Vector2i(x, y))
			if cell == null or not (cell.occupant is Tile) or TriggerCore.of(cell.occupant) != null:
				continue
			cell.occupant = null
			var forbidden := BoardGenerator.colors_that_would_match(cell)
			cell.occupant = Tile.make_normal(BoardGenerator.pick_color(board.colors, forbidden, rng))
