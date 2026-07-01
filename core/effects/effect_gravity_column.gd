## Gravity for one column. A pit (or a gap, on a non-rectangular board)
## splits the physical column into independent falling segments: a segment
## never compacts across a pit/gap, so tiles above a destroyed pit-covering
## tile don't fall through it, and tiles below a pit don't get pulled up
## through it either. The cells a pit pins (see CellKind.pinned_neighbors)
## are refilled directly by it — that's the local "new tile emerges from
## the pit" source for whichever segment sits on that side.
## See .claude/skills/match3-board-model/SKILL.md.
class_name EffectGravityColumn
extends Effect

var x: int

func _init(p_x: int) -> void:
	x = p_x

func execute(board: BoardGraph) -> Array[Effect]:
	var column := board.column_cells_top_to_bottom(x)

	var pinned: Dictionary = {}  # GridCell -> true
	for cell in column:
		if cell == null:
			continue
		for neighbor in cell.kind.pinned_neighbors(cell):
			pinned[neighbor] = true

	var effects: Array[Effect] = []
	for cell: GridCell in pinned.keys():
		if cell.occupant == null:
			effects.append(EffectSpawnTile.new(cell))

	for segment in _segments(column, pinned):
		effects.append_array(_resolve_segment(segment))
	return effects

## Splits the column into contiguous holdable runs, breaking at pits, gaps,
## and pinned cells (which are their own independent one-cell "segment"
## handled above, not by generic compaction).
static func _segments(column: Array[GridCell], pinned: Dictionary) -> Array:
	var segments: Array = []
	var current: Array[GridCell] = []
	for cell in column:
		if cell != null and cell.kind.can_hold_tile() and not pinned.has(cell):
			current.append(cell)
		elif not current.is_empty():
			segments.append(current)
			current = []
	if not current.is_empty():
		segments.append(current)
	return segments

## Standard "compact non-null down, spawn for leftover gaps at the top"
## pass, scoped to a single segment instead of the whole column.
static func _resolve_segment(segment: Array[GridCell]) -> Array[Effect]:
	var write_index := segment.size() - 1
	for read_index in range(segment.size() - 1, -1, -1):
		var cell: GridCell = segment[read_index]
		if cell.occupant == null:
			continue
		if not cell.occupant.can_fall():
			# Fixed obstacle: stays put, and slots below it (already visited,
			# on the far side of the barrier) are no longer reachable by
			# tiles still above it.
			write_index = read_index - 1
			continue
		if write_index != read_index:
			segment[write_index].occupant = cell.occupant
			cell.occupant = null
		write_index -= 1

	# All gaps in this segment (indices 0..write_index, 0 = segment top) are
	# one contiguous run immediately above the segment's own top boundary —
	# every one of them starts exactly `gap_count` cells above its target,
	# a CONSTANT for the whole batch, not scaled per gap. That's what keeps
	# it collision-free (a start row is always above the segment's topmost
	# real row, so it can never coincide with a still-existing tile) while
	# still landing at the same time as the segment's own settling tiles.
	var gap_count := write_index + 1
	var effects: Array[Effect] = []
	for i in range(write_index, -1, -1):
		effects.append(EffectSpawnTile.new(segment[i], gap_count))
	return effects
