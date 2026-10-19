## An arrow blaster's blast along `axis`; the view shoots bolts toward both ends of the line.
class_name EffectArrowBlast
extends EffectBlast

var axis: ArrowBlasterCore.Axis

func _init(p_origin: GridCell, p_axis: ArrowBlasterCore.Axis, p_cells: Array[GridCell], p_source: Tile = null) -> void:
	super(p_origin, p_cells, p_source)
	axis = p_axis
