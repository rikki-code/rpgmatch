## A tile absorbed by a combination: gone without scoring as destroyed.
class_name EffectConsumeTile
extends Effect

var tile: Tile
var cell: GridCell

func _init(p_tile: Tile, p_cell: GridCell) -> void:
	tile = p_tile
	cell = p_cell
