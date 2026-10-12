## Greedy AI board move. Scores everything a player could do — plain swaps,
## swaps that set off a bonus tile, combining two bonus tiles, double-click
## detonating one — by roughly how many tiles it clears, keeps the best.
## A heuristic over blast previews (TriggerCore.blast_cells), not a full
## cascade simulation.
class_name AiMovePicker
extends RefCounted

class Move:
	enum Kind { SWAP, DETONATE }
	var kind: Kind
	var cell_a: GridCell
	## null for DETONATE.
	var cell_b: GridCell
	var value: float

	func _init(p_kind: Kind, p_cell_a: GridCell, p_cell_b: GridCell, p_value: float) -> void:
		kind = p_kind
		cell_a = p_cell_a
		cell_b = p_cell_b
		value = p_value

## A combined blast outdoes its parts (Bomb+Bomb = bigger radius, Prism+X =
## X everywhere) — union of both blasts undersells it.
const COMBINE_FACTOR := 1.5
## A 4/5-match leaves a bonus tile behind — worth something beyond its tiles.
const BONUS_SPAWN_VALUE := {4: 3.0, 5: 6.0}

## null when there's no legal move at all.
static func best_move(board: BoardGraph) -> Move:
	var best: Move = null
	for cell: GridCell in board.all_cells():
		if cell.occupant is Tile and (cell.occupant as Tile).is_manually_triggerable():
			best = _better(best, Move.new(Move.Kind.DETONATE, cell, null, _blast_value(cell.occupant, cell, board)))
		for dir: GridDirection.Dir in [GridDirection.Dir.RIGHT, GridDirection.Dir.DOWN]:
			var other := cell.neighbor(dir)
			if other != null:
				best = _better(best, Move.new(Move.Kind.SWAP, cell, other, _swap_value(cell, other, board)))
	return best

static func _better(best: Move, candidate: Move) -> Move:
	if candidate.value <= 0.0:
		return best
	if best == null or candidate.value > best.value:
		return candidate
	return best

static func _swap_value(a: GridCell, b: GridCell, board: BoardGraph) -> float:
	if not (a.occupant is Tile) or not (b.occupant is Tile):
		return 0.0
	var tile_a: Tile = a.occupant
	var tile_b: Tile = b.occupant
	if tile_a.blocks_swap() or tile_b.blocks_swap():
		return 0.0
	if tile_a.can_combine_with(tile_b) and tile_b.can_combine_with(tile_a):
		return _combine_value(tile_a, tile_b, b, board)

	board.swap_occupants(a, b)
	var value := 0.0
	var matched: Array[GridCell] = []
	for group in MatchFinder.find_matches(board):
		if group.cells.has(a) or group.cells.has(b):
			matched.append_array(group.cells)
			value += group.cells.size() + BONUS_SPAWN_VALUE.get(mini(group.cells.size(), 5), 0.0)
	if not matched.is_empty():
		value += _splash_trigger_value(a, matched, board) + _splash_trigger_value(b, matched, board)
	board.swap_occupants(a, b)
	return value

## A swapped bonus tile next to the match it helped make detonates from the
## splash (SwapSplashTriggerBehavior) — count its blast too.
static func _splash_trigger_value(cell: GridCell, matched: Array[GridCell], board: BoardGraph) -> float:
	if matched.has(cell) or not (cell.occupant is Tile):
		return 0.0
	var tile: Tile = cell.occupant
	if not tile.behaviors.any(func(b: TileBehavior) -> bool: return b is SwapSplashTriggerBehavior):
		return 0.0
	for neighbor: GridCell in cell.neighbors.values():
		if neighbor != null and matched.has(neighbor):
			return _blast_value(tile, cell, board)
	return 0.0

static func _blast_value(tile: Tile, cell: GridCell, board: BoardGraph) -> float:
	var core := TriggerCore.of(tile)
	if core == null:
		return 0.0
	var value := 0.0
	for target in core.blast_cells(tile, cell, board):
		if target != cell and target.occupant is Tile:
			value += 1.0
	return value

static func _combine_value(tile_a: Tile, tile_b: Tile, cell: GridCell, board: BoardGraph) -> float:
	var core_a := TriggerCore.of(tile_a)
	var core_b := TriggerCore.of(tile_b)
	if core_a == null or core_b == null:
		return 0.0
	var hit := {}
	for target in core_a.blast_cells(tile_a, cell, board):
		if target.occupant is Tile:
			hit[target] = true
	for target in core_b.blast_cells(tile_b, cell, board):
		if target.occupant is Tile:
			hit[target] = true
	return hit.size() * COMBINE_FACTOR
