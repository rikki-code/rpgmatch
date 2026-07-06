## Fires a bonus tile's TriggerCore as its own resolver step, one tick after
## EffectPlaceTile put it on the board — see TriggerCore._place_and_trigger.
## Splitting placement and detonation into two queued effects (instead of
## calling trigger() inline right after the mutation) is what gives the view
## a real effect_applied in between: it builds/shows the tile's node from the
## first effect before this one empties the cell again, instead of both
## happening before the view ever learns the tile existed.
class_name EffectTriggerTile
extends Effect

var cell: GridCell
var tile: Tile

func _init(p_cell: GridCell, p_tile: Tile) -> void:
	cell = p_cell
	tile = p_tile

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant != tile:
		return []
	return TriggerCore.of(tile).trigger(tile, cell, board)
