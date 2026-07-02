## Tags a bomb's blast for the view — BoardView3D plays a flash on every
## cell in `cells` when it sees this effect go by (see
## view/effects/tile_explosion.tscn) — then turns into an EffectBlastDamage
## per cell (a direct explosion hit, not the soft splash EffectSplashDamage
## delivers). A bomb caught in the radius reacts via BombCore.on_damage and
## chains; anything else with no opinion just dies (see
## BoardEntity.on_damage).
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
		effects.append(EffectBlastDamage.new(cell, 1))
	return effects
