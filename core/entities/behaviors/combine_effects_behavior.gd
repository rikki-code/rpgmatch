## Lets two bonus tiles that get swapped onto each other merge instead of an
## ordinary color-match swap (see SwapController — a combine takes priority
## over "swap must create a match"). The actual recipe (bomb+bomb sums
## radius, bomb+arrow keeps the arrow's axis, PrismCore's asymmetric "absorb
## anything" recipe, ...) lives on TriggerCore._do_combine_with/
## can_combine_with_core; this behavior only bridges the two tiles' cores
## together.
class_name CombineEffectsBehavior
extends TileBehavior

var core: TriggerCore

func _init(p_core: TriggerCore) -> void:
	core = p_core

func can_combine_with(_self_tile: Tile, other_tile: Tile) -> bool:
	var other_core := TriggerCore.of(other_tile)
	return other_core != null and core.can_combine_with_core(other_core)

func combine_with(_self_tile: Tile, other_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var other_core := TriggerCore.of(other_tile)
	if other_core == null:
		return []
	return core._do_combine_with(other_core, cell, board)
