## Tags a prism's blast for the view — BoardView3D fires a colored magic bolt
## from `origin` at each cell in `cells` (see BoardView3D._play_prism_blast)
## — then turns into an EffectBlastDamage per cell, same direct-hit delivery
## as EffectBombBlast/EffectArrowBlast.
class_name EffectPrismBlast
extends Effect

var origin: GridCell
var cells: Array[GridCell]
## Board color index the bolts should be tinted. -1 = no single color (two
## prisms combined into a whole-board blast, see PrismCore._do_combine_with) — view
## falls back to a neutral tint.
var color: int

func _init(p_origin: GridCell, p_cells: Array[GridCell], p_color: int = -1) -> void:
	origin = p_origin
	cells = p_cells
	color = p_color

func execute(_board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for cell in cells:
		effects.append(EffectBlastDamage.new(cell, 1))
	return effects
