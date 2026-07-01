class_name EffectDestroyTile
extends Effect

var cell: GridCell

func _init(p_cell: GridCell) -> void:
	cell = p_cell

func execute(board: BoardGraph) -> Array[Effect]:
	if not (cell.occupant is Tile):
		return []
	var tile: Tile = cell.occupant
	cell.occupant = null
	return tile.on_matched(cell, board)
