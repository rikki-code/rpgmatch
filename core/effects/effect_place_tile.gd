## Drops an already-built Tile onto `cell` as its own resolver step — used by
## TriggerCore._place_and_trigger so a combined/spawned bonus tile gets a
## genuine effect_applied before whatever triggers it next (see
## EffectTriggerTile), instead of the placement being an inline mutation the
## view never gets a chance to see.
class_name EffectPlaceTile
extends Effect

var cell: GridCell
var tile: Tile
var fall_distance: int = 0
var reveal_distance: int = 0

func _init(p_cell: GridCell, p_tile: Tile) -> void:
	cell = p_cell
	tile = p_tile

func execute(_board: BoardGraph) -> Array[Effect]:
	if not cell.kind.can_hold_tile():
		return []
	cell.occupant = tile
	return []
