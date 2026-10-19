## A prism's blast; the view fires a bolt at every cell, tinted with `color`
## (a board color index, -1 = neutral for a whole-board combo).
class_name EffectPrismBlast
extends EffectBlast

var color: int

func _init(p_origin: GridCell, p_cells: Array[GridCell], p_color: int = -1, p_source: Tile = null) -> void:
	super(p_origin, p_cells, p_source)
	color = p_color
