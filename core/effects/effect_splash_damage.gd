## Generic *soft* damage delivery: dispatches to whatever occupies `cell` via
## BoardEntity.on_splash_damage. A plain color tile has no override, so it
## just ignores a hit (no HP concept) — only entities that actually care
## react. This is what lets an ordinary tile's destruction splash (see
## SplashDamageBehavior) nudge a bomb (see SwapSplashTriggerBehavior) without
## either of them knowing what the other is. Contrast with
## EffectBlastDamage/on_damage: a direct explosion hit, unconditional,
## destroys by default instead of being ignored by default.
class_name EffectSplashDamage
extends Effect

var cell: GridCell
var amount: int

func _init(p_cell: GridCell, p_amount: int = 1) -> void:
	cell = p_cell
	amount = p_amount

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant == null:
		return []
	return cell.occupant.on_splash_damage(amount, cell, board)
