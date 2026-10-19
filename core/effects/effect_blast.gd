## Base of every explosion: damages each cell in `cells`. `source` is the tile
## that detonated (null if none), so the view can wait for its fuse.
class_name EffectBlast
extends Effect

var origin: GridCell
var cells: Array[GridCell]
var source: Tile

func _init(p_origin: GridCell, p_cells: Array[GridCell], p_source: Tile = null) -> void:
	origin = p_origin
	cells = p_cells
	source = p_source

func execute(_board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for cell in cells:
		effects.append(EffectBlastDamage.new(cell, 1))
	return effects
