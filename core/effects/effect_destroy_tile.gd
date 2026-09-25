class_name EffectDestroyTile
extends Effect

var cell: GridCell
## Set by execute() — lets score/quest listeners read it post-hoc.
var removed_entity: BoardEntity

func _init(p_cell: GridCell) -> void:
	cell = p_cell

func execute(board: BoardGraph) -> Array[Effect]:
	if not (cell.occupant is Tile):
		return []
	var tile: Tile = cell.occupant
	cell.occupant = null
	removed_entity = tile
	return tile.on_matched(cell, board)
