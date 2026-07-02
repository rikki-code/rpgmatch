## A direct hit from an explosion (see EffectBombBlast) — dispatches to
## BoardEntity.on_damage. Separate from EffectSplashDamage/on_splash_damage
## (a soft nudge most things ignore, see SplashDamageBehavior) because a
## blast is a much stronger, unconditional hit: whatever it touches dies by
## default, no HP required — only things that want to react differently
## (e.g. a bomb chain-reacting with its own explosion, see
## BombCore.on_damage) override on_damage themselves.
class_name EffectBlastDamage
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
