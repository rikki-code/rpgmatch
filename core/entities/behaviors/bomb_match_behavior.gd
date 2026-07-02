## Explodes when this tile is destroyed as part of a genuine MatchFinder
## run — only meaningful for a bomb that also carries ColorBehavior (see
## Tile.make_color_bomb); a plain colorless bomb can never be part of a
## match, so it doesn't get this piece at all (see Tile.make_bomb). Not to
## be confused with BombCore.on_damage: being destroyed by an actual
## explosion is a different hook entirely.
class_name BombMatchBehavior
extends TileBehavior

var core: BombCore

func _init(p_core: BombCore) -> void:
	core = p_core

func on_matched(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return core.trigger(self_tile, cell, board)
