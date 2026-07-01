## Generic damage delivery: dispatches to whatever occupies `cell` via
## BoardEntity.on_damage. A plain color tile has no on_damage override, so it
## just ignores a hit (no HP concept) — only entities that actually care
## (a bomb, later an HP-bearing obstacle) react. This is what lets an
## ordinary tile's destruction splash (see SplashDamageBehavior) or a
## player's direct detonate action (see DetonateController) trigger a bomb
## without either of them knowing what a bomb is.
class_name EffectDamageEntity
extends Effect

var cell: GridCell
var amount: int

func _init(p_cell: GridCell, p_amount: int = 1) -> void:
	cell = p_cell
	amount = p_amount

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant == null:
		return []
	return cell.occupant.on_damage(amount, cell, board)
