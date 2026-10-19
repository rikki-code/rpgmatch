## Turns whatever is on `cell` into a fresh (black, non-color-matching) bomb
## tile — see Tile.make_bomb. Used both as the reward for a big match (see
## EffectResolveMatchGroup) and for a random bomb drop during gravity
## refill (see EffectSpawnTile).
class_name EffectSpawnBombTile
extends EffectAppearTile


func _init(p_cell: GridCell) -> void:
	cell = p_cell

func execute(_board: BoardGraph) -> Array[Effect]:
	if not cell.kind.can_hold_tile():
		return []
	tile = Tile.make_bomb()
	cell.occupant = tile
	return []
