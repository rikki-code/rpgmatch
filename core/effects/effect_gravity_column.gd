## Gravity for one column. A pit (or a gap, on a non-rectangular board) is
## just an ordinary segment boundary — nothing about it is special-cased:
## it splits the physical column into independent falling segments, and
## each segment falls + top-spawns exactly like a segment touching the
## board's own edge would. A segment resting on a pit simply has the pit as
## its floor; a segment starting right after a pit has the pit as its
## ceiling/spawn source instead of the board's real top edge. No cell is
## ever frozen in place.
## See .claude/skills/match3-board-model/SKILL.md.
class_name EffectGravityColumn
extends Effect

var x: int

func _init(p_x: int) -> void:
	x = p_x

func execute(board: BoardGraph) -> Array[Effect]:
	var column := board.column_cells_top_to_bottom(x)

	var effects: Array[Effect] = []
	for segment in _segments(column):
		effects.append_array(_resolve_segment(segment))
	return effects

## Splits the column into contiguous holdable runs, breaking at pits and
## gaps (a non-rectangular board can have no cell at all at some (x, y)).
static func _segments(column: Array[GridCell]) -> Array:
	var segments: Array = []
	var current: Array[GridCell] = []
	for cell in column:
		if cell != null and cell.kind.can_hold_tile():
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
	#
	# That start row can still land inside whatever segment is physically
	# above this one on the board (e.g. tiles resting above a pit) — gap i
	# should only become visible once it's `i + 1` cells from its target,
	# i.e. right as it crosses this segment's own top boundary, never
	# before.
	var gap_count := write_index + 1
	var effects: Array[Effect] = []
	for i in range(write_index, -1, -1):
		effects.append(EffectSpawnTile.new(segment[i], gap_count, i + 1))
	return effects
