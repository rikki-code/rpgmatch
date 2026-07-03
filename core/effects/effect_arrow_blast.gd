## Tags an arrow blaster's blast for the view — BoardView3D plays the same
## per-cell flash as EffectBombBlast (see view/effects/tile_explosion.tscn)
## plus a pair of energy bolts shooting out from `origin` toward both ends of
## the line (see BoardView3D._play_arrow_blast) — then turns into an
## EffectBlastDamage per cell, same as a bomb's blast.
class_name EffectArrowBlast
extends Effect

var origin: GridCell
var axis: ArrowBlasterCore.Axis
var cells: Array[GridCell]

func _init(p_origin: GridCell, p_axis: ArrowBlasterCore.Axis, p_cells: Array[GridCell]) -> void:
	origin = p_origin
	axis = p_axis
	cells = p_cells

func execute(_board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for cell in cells:
		effects.append(EffectBlastDamage.new(cell, 1))
	return effects
