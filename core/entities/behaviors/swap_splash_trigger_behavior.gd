## Detonates a bonus tile from an ordinary tile's on-destroy splash (see
## SplashDamageBehavior, EffectSplashDamage/on_splash_damage) — but only if
## this tile itself was one of the two tiles just swapped into the match
## that caused that splash (BoardGraph.swapped_tiles, reset each turn by
## PhasePlayerInput.enter). An unrelated match happening to sit next to an
## otherwise-untouched bonus tile must not set it off — that's what the gate
## is for. Contrast with TriggerCore.on_damage, which reacts unconditionally
## to a direct explosion hit.
class_name SwapSplashTriggerBehavior
extends TileBehavior

var core: TriggerCore

func _init(p_core: TriggerCore) -> void:
	core = p_core

func on_splash_damage(self_tile: Tile, _amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if not board.swapped_tiles.has(self_tile):
		return []
	return core.trigger(self_tile, cell, board)
