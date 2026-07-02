## Base for tile behaviors (composition, not subclassing). A Tile carries a
## list of these; every future bonus/penalty tile is a new TileBehavior
## implementing the hooks it cares about. See
## .claude/skills/match3-add-mechanic/SKILL.md.
class_name TileBehavior
extends RefCounted

func can_match_with(_self_tile: Tile, _other_tile: Tile) -> bool:
	return false

func on_matched(_self_tile: Tile, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func on_turn_tick(_self_tile: Tile, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func on_damage(_self_tile: Tile, _amount: int, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func on_splash_damage(_self_tile: Tile, _amount: int, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func blocks_swap(_self_tile: Tile) -> bool:
	return false

## Whether the player can directly activate this tile
func is_manually_triggerable(_self_tile: Tile) -> bool:
	return false

func manual_trigger(_self_tile: Tile, _cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	return []

func visual_kind(_self_tile: Tile) -> StringName:
	return &""
