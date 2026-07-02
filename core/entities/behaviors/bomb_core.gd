## Shared explosion state for one bomb tile instance, AND the one trigger
## every bomb variant always has: a direct hit from another explosion (see
## BoardEntity.on_damage/EffectBlastDamage) always chains, unconditionally —
## no bomb variant would ever want to opt out of that — so it lives here
## instead of yet another thin wrapper behavior.
##
## A bomb is composed of BombCore plus whichever other thin TileBehaviors
## apply (BombManualTriggerBehavior, BombMatchBehavior,
## BombSwapSplashBehavior — see Tile.make_bomb/make_color_bomb); all of them
## hold a reference to the same BombCore so only one can ever actually
## detonate it (`_exploded` guard) and they agree on blast radius.
class_name BombCore
extends TileBehavior

enum Shape { MANHATTAN, SQUARE }
var shape: Shape
var radius: int
var _exploded := false

func _init(p_radius: int = 1, p_shape: Shape = Shape.MANHATTAN) -> void:
	radius = p_radius
	shape = p_shape

func on_damage(self_tile: Tile, _amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return trigger(self_tile, cell, board)

func visual_kind(_self_tile: Tile) -> StringName:
	return &"bomb"

func trigger(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if _exploded:
		return []
	_exploded = true
	if cell.occupant == self_tile:
		cell.occupant = null
	if shape == Shape.MANHATTAN:
		return [EffectBombBlast.new(cell, board.cells_within_manhattan_radius(cell, radius))]
	else:
		return [EffectBombBlast.new(cell, board.cells_within_square_radius(cell, radius))]
