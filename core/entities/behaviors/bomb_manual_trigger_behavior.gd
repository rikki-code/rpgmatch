## Lets a player pop this bomb on demand (double-click, see
## DetonateController) instead of only reacting to matches/damage. Shares
## its explosion with whatever other BombBehavior-family pieces are on the
## same tile via `core` — see BombCore.
class_name BombManualTriggerBehavior
extends TileBehavior

var core: BombCore

func _init(p_core: BombCore) -> void:
	core = p_core

func is_manually_triggerable(_self_tile: Tile) -> bool:
	return true

func manual_trigger(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return core.trigger(self_tile, cell, board)
