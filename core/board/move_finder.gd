## Every legal move on a board, each valued by the combat points it would
## score the way ScoreTracker counts them (match tiles in full, blast tiles
## x BLAST_POWER_FACTOR, match tiles x `match_weight` — the battle's
## BattleContext.power_multiplier, so the ranking matches real power) — plain swaps, swaps that set off a bonus tile,
## combining two bonus tiles, double-click detonating one. Used by AI turns,
## the idle-player hint and the shuffle's "has a move" check. A heuristic over
## blast previews (TriggerCore.blast_cells), not a full cascade simulation.
class_name MoveFinder
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
const BLAST := ScoreTracker.BLAST_POWER_FACTOR

## null when there's no legal move at all.
static func best_move(board: BoardGraph, match_weight := 1.0) -> Move:
	var best: Move = null
	for move in all_moves(board, false, match_weight):
		if best == null or move.value > best.value:
			best = move
	return best

## The best move with probability `skill`, otherwise any legal move.
static func pick_move(board: BoardGraph, skill: float, rng: RandomNumberGenerator, match_weight := 1.0) -> Move:
	if rng.randf() < skill:
		return best_move(board, match_weight)
	var moves := all_moves(board)
	return null if moves.is_empty() else moves[rng.randi_range(0, moves.size() - 1)]

static func has_move(board: BoardGraph) -> bool:
	return not all_moves(board, true).is_empty()

## Every legal move (value > 0); `first_only` stops at the first one found.
static func all_moves(board: BoardGraph, first_only := false, match_weight := 1.0) -> Array[Move]:
	var moves: Array[Move] = []
	for cell: GridCell in board.all_cells():
		if cell.occupant is Tile and (cell.occupant as Tile).is_manually_triggerable():
			moves.append(Move.new(Move.Kind.DETONATE, cell, null, _blast_value(cell.occupant, cell, board)))
		for dir: GridDirection.Dir in [GridDirection.Dir.RIGHT, GridDirection.Dir.DOWN]:
			var other := cell.neighbor(dir)
			if other != null:
				var value := _swap_value(cell, other, board, match_weight)
				if value > 0.0:
					moves.append(Move.new(Move.Kind.SWAP, cell, other, value))
		if first_only and not moves.is_empty():
			break
	return moves

static func _swap_value(a: GridCell, b: GridCell, board: BoardGraph, match_weight: float) -> float:
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
			for cell in group.cells:
				value += cell.occupant.score_value() * match_weight
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
	var value := float(tile.score_value())
	for target in core.blast_cells(tile, cell, board):
		if target != cell and target.occupant is Tile:
			value += target.occupant.score_value()
	return value * BLAST

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
	var value := 0.0
	for target: GridCell in hit:
		value += target.occupant.score_value()
	return value * COMBINE_FACTOR * BLAST
