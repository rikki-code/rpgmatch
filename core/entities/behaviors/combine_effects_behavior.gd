## Lets two bonus tiles that get swapped onto each other merge into one
## stronger bonus and detonate immediately, instead of an ordinary color-match
## swap (see SwapController — a combine takes priority over "swap must create
## a match"). The actual recipe (bomb+bomb sums radius, bomb+arrow keeps the
## arrow's axis, arrow+arrow becomes Axis.BOTH — see ArrowBlasterCore.Axis)
## lives on TriggerCore._do_combine_with; this behavior only wires the two tiles'
## cores together and fires the result at the destination cell.
class_name CombineEffectsBehavior
extends TileBehavior

var core: TriggerCore

func _init(p_core: TriggerCore) -> void:
	core = p_core

func can_combine_with(_self_tile: Tile, other_tile: Tile) -> bool:
	var other_core := _peer_core(other_tile)
	return other_core != null and core._do_combine_with(other_core) != null

func combine_with(_self_tile: Tile, other_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var other_core := _peer_core(other_tile)
	if other_core == null:
		return []
	var combined_tile := core._do_combine_with(other_core)
	if combined_tile == null:
		return []
	cell.occupant = combined_tile
	var combined_core := _trigger_core_of(combined_tile)
	return combined_core.trigger(combined_tile, cell, board)

static func _peer_core(other_tile: Tile) -> TriggerCore:
	for behavior in other_tile.behaviors:
		if behavior is CombineEffectsBehavior:
			return behavior.core
	return null

static func _trigger_core_of(tile: Tile) -> TriggerCore:
	for behavior in tile.behaviors:
		if behavior is TriggerCore:
			return behavior
	return null
