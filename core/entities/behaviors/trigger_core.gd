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
##
## Combining two bonus tiles is also decided here: `can_combine_with_core` is
## a pure yes/no (checked from both tiles before anything mutates, see
## CombineEffectsBehavior — named apart from TileBehavior.can_combine_with,
## which takes Tiles, not TriggerCores, and can't be overridden with a
## different signature), `_do_combine_with` performs it and returns whatever
## Effects result — not necessarily a single tile placed at `cell` (see
## PrismCore, whose recipe spawns/triggers the partner's own kind across many
## cells instead).
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

func can_combine_with_core(_other: TriggerCore) -> bool:
	return false

func _do_combine_with(_other: TriggerCore, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func spawn_similar_tile() -> Tile:
	return null

static func of(tile: Tile) -> TriggerCore:
	for behavior in tile.behaviors:
		if behavior is TriggerCore:
			return behavior
	return null

static func _place_and_trigger(tile: Tile, cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return [EffectPlaceTile.new(cell, tile), EffectTriggerTile.new(cell, tile)]
