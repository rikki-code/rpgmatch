## Detonates a bonus tile when it's destroyed as part of a genuine
## MatchFinder run — only meaningful for a variant that also carries
## ColorBehavior (see Tile.make_color_bomb); a colorless bonus tile can never
## be part of a match, so it doesn't get this piece at all (see
## Tile.make_bomb/make_arrow_blaster). Not to be confused with
## TriggerCore.on_damage: being destroyed by an actual explosion is a
## different hook entirely.
class_name MatchTriggerBehavior
extends TileBehavior

var core: TriggerCore

func _init(p_core: TriggerCore) -> void:
	core = p_core

func on_matched(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return core.trigger(self_tile, cell, board)
