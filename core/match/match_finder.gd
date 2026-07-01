## "Match-3" here means the classic straight run: three or more same-color
## tiles in an unbroken row or column, not just any connected same-color
## blob. A cell only counts once it's part of such a run. Runs that touch
## (an L/T/cross shape from a single swap) are still coalesced into one
## MatchGroup, since they resolve as a single destroy event.
class_name MatchFinder
extends RefCounted

static func find_matches(board: BoardGraph) -> Array[MatchGroup]:
	var matched: Dictionary = {}  # GridCell -> true
	_collect_runs(board, GridDirection.Dir.RIGHT, matched)
	_collect_runs(board, GridDirection.Dir.DOWN, matched)

	var visited: Dictionary = {}  # Vector2i -> true
	var groups: Array[MatchGroup] = []
	for cell: GridCell in matched.keys():
		if visited.has(cell.position):
			continue
		groups.append(_flood_fill_within(cell, matched, visited))
	return groups

## Walks every straight line along `axis_dir` (RIGHT for rows, DOWN for
## columns) and flags every cell that's part of a run of length >= 3.
static func _collect_runs(board: BoardGraph, axis_dir: GridDirection.Dir, matched: Dictionary) -> void:
	var behind_dir := GridDirection.opposite(axis_dir)
	for cell: GridCell in board.all_cells():
		if not (cell.occupant is Tile):
			continue
		var behind := cell.neighbor(behind_dir)
		if behind != null and behind.occupant is Tile and _matches(behind.occupant, cell.occupant):
			continue  # not a run start; the actual start of this run will collect it

		var run: Array[GridCell] = [cell]
		var current := cell
		while true:
			var next := current.neighbor(axis_dir)
			if next == null or not (next.occupant is Tile):
				break
			var current_tile: Tile = current.occupant
			if not _matches(current_tile, next.occupant):
				break
			run.append(next)
			current = next

		if run.size() >= 3:
			for c in run:
				matched[c] = true

static func _matches(a: Tile, b: Tile) -> bool:
	return a.can_match_with(b) and b.can_match_with(a)

## Connected-component flood fill, but restricted to cells already flagged
## by _collect_runs — this only merges touching runs, it never grows a
## match from a blob smaller than 3 in a line.
static func _flood_fill_within(start: GridCell, matched: Dictionary, visited: Dictionary) -> MatchGroup:
	var group := MatchGroup.new()
	var stack: Array[GridCell] = [start]
	visited[start.position] = true
	while not stack.is_empty():
		var current: GridCell = stack.pop_back()
		group.cells.append(current)
		for dir in GridDirection.ALL:
			var neighbor := current.neighbor(dir)
			if neighbor == null or visited.has(neighbor.position) or not matched.has(neighbor):
				continue
			if not _matches(current.occupant as Tile, neighbor.occupant as Tile):
				continue
			visited[neighbor.position] = true
			stack.append(neighbor)
	return group
