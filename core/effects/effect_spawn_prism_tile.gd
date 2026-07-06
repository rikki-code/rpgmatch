## Turns whatever is on `cell` into a fresh prism tile — see Tile.make_prism.
## Reward for a straight run of BOMB_MATCH_THRESHOLD+ cells (a blob/L/T shape
## of the same size spawns a bomb instead — see
## EffectResolveMatchGroup._is_straight_line), mirrors
## EffectSpawnBombTile/EffectSpawnArrowBlasterTile.
class_name EffectSpawnPrismTile
extends Effect

var cell: GridCell
var fall_distance: int = 0
var reveal_distance: int = 0

func _init(p_cell: GridCell) -> void:
	cell = p_cell

func execute(_board: BoardGraph) -> Array[Effect]:
	if not cell.kind.can_hold_tile():
		return []
	cell.occupant = Tile.make_prism()
	return []
