## Tags a bomb's blast for the view — BoardView3D plays a flash on every
## cell in `cells` when it sees this effect go by (see
## view/effects/tile_explosion.tscn) — then turns into the actual
## EffectDestroyTile per cell, so the real board mutation is still just an
## ordinary destroy per cell, cascading exactly like any other destroy (a
## bomb caught in another bomb's blast chains normally).
class_name EffectBombBlast
extends Effect

var origin: GridCell
var cells: Array[GridCell]

func _init(p_origin: GridCell, p_cells: Array[GridCell]) -> void:
	origin = p_origin
	cells = p_cells

func execute(_board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for cell in cells:
		effects.append(EffectDestroyTile.new(cell))
	return effects
