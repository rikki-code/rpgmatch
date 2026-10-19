## Turns whatever is on `cell` into a fresh arrow blaster tile — see
## Tile.make_arrow_blaster. Reward for a length-4 straight match (see
## EffectResolveMatchGroup), mirrors EffectSpawnBombTile.
class_name EffectSpawnArrowBlasterTile
extends EffectAppearTile

var axis: ArrowBlasterCore.Axis
var extra_lines: int

func _init(p_cell: GridCell, p_axis: ArrowBlasterCore.Axis, p_extra_lines: int = 0) -> void:
	cell = p_cell
	axis = p_axis
	extra_lines = p_extra_lines

func execute(_board: BoardGraph) -> Array[Effect]:
	if not cell.kind.can_hold_tile():
		return []
	tile = Tile.make_arrow_blaster(axis, extra_lines)
	cell.occupant = tile
	return []
