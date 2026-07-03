## Shared base for a bonus tile's "one detonation, several ways to trigger
## it" state. A direct hit from another explosion (see
## BoardEntity.on_damage/EffectBlastDamage) always chains, unconditionally —
## no variant (BombCore, ArrowBlasterCore, ...) would ever want to opt out of
## that, so the `_triggered` guard and on_damage wiring live here once instead
## of being copy-pasted per bonus tile. Subclasses only implement
## `_do_trigger` with their own blast shape.
##
## A bonus tile is composed of one TriggerCore plus whichever thin
## TileBehaviors apply (ManualTriggerBehavior, MatchTriggerBehavior,
## SwapSplashTriggerBehavior — see Tile.make_bomb/make_arrow_blaster), all
## holding a reference to the same TriggerCore so only one can ever actually
## detonate it.
class_name TriggerCore
extends TileBehavior

var _triggered := false

func on_damage(self_tile: Tile, _amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return trigger(self_tile, cell, board)

func trigger(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if _triggered:
		return []
	_triggered = true
	if cell.occupant == self_tile:
		cell.occupant = null
	return _do_trigger(self_tile, cell, board)

func _do_trigger(_self_tile: Tile, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func _do_combine_with(_other: TriggerCore) -> Tile:
	return null
