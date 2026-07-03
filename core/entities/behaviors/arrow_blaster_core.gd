## Arrow blaster's own blast shape on top of TriggerCore's shared "one
## detonation, several triggers" plumbing (`_triggered` guard, on_damage
## wiring — see TriggerCore).
##
## An arrow blaster is composed of ArrowBlasterCore plus whichever other thin
## TileBehaviors apply (ManualTriggerBehavior, SwapSplashTriggerBehavior —
## see Tile.make_arrow_blaster); both hold a reference to the same
## ArrowBlasterCore (as a TriggerCore) so only one can ever actually detonate
## it.
class_name ArrowBlasterCore
extends TriggerCore

## ROW: wipes the full row(s) it sits on (blast extends left/right).
## COLUMN: wipes the full column(s) it sits on (blast extends up/down).
## Set opposite to the match's own orientation — a vertical match (a column
## run) spawns a ROW blaster and vice versa (see EffectResolveMatchGroup).
## BOTH: wipes row and column at once — only reachable by combining two
## arrow blasters (see _do_combine_with), never spawned from a match.
enum Axis { ROW, COLUMN, BOTH }

var axis: Axis
## How many extra parallel rows/columns beyond the one the tile sits on are
## also destroyed (symmetric on both sides, like BombCore.radius). 0 = only
## its own row/column.
var extra_lines: int

func _init(p_axis: Axis, p_extra_lines: int = 0) -> void:
	axis = p_axis
	extra_lines = p_extra_lines

func visual_kind(_self_tile: Tile) -> StringName:
	match axis:
		Axis.ROW:
			return &"arrow_blaster_row"
		Axis.COLUMN:
			return &"arrow_blaster_column"
		_:
			return &"arrow_blaster_both"

func _do_trigger(_self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var cells: Array[GridCell]
	match axis:
		Axis.ROW:
			cells = board.cells_within_row_band(cell, extra_lines)
		Axis.COLUMN:
			cells = board.cells_within_column_band(cell, extra_lines)
		_:
			cells = board.cells_within_row_band(cell, extra_lines)
			for column_cell in board.cells_within_column_band(cell, extra_lines):
				if not cells.has(column_cell):
					cells.append(column_cell)
	return [EffectArrowBlast.new(cell, axis, cells)]

func _do_combine_with(other: TriggerCore) -> Tile:
	if other is ArrowBlasterCore:
		return Tile.make_arrow_blaster(Axis.BOTH, extra_lines + other.extra_lines)
	if other is BombCore:
		return Tile.make_arrow_blaster(axis, extra_lines + other.radius)
	return null
