## Lets a player pop a bonus tile on demand (double-click, see
## DetonateController) instead of only reacting to matches/damage. Shares its
## detonation with whatever other trigger behavior is on the same tile via
## `core` — see TriggerCore.
class_name ManualTriggerBehavior
extends TileBehavior

var core: TriggerCore

func _init(p_core: TriggerCore) -> void:
	core = p_core

func is_manually_triggerable(_self_tile: Tile) -> bool:
	return true

func manual_trigger(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return core.trigger(self_tile, cell, board)
