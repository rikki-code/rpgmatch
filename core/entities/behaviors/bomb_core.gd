## Bomb's own blast shape on top of TriggerCore's shared "one detonation,
## several triggers" plumbing (`_triggered` guard, on_damage wiring — see
## TriggerCore).
##
## A bomb is composed of BombCore plus whichever other thin TileBehaviors
## apply (ManualTriggerBehavior, MatchTriggerBehavior,
## SwapSplashTriggerBehavior — see Tile.make_bomb/make_color_bomb); all of
## them hold a reference to the same BombCore (as a TriggerCore) so only one
## can ever actually detonate it and they agree on blast radius.
class_name BombCore
extends TriggerCore

enum Shape { MANHATTAN, SQUARE }
var shape: Shape
var radius: int

func _init(p_radius: int = 1, p_shape: Shape = Shape.MANHATTAN) -> void:
	radius = p_radius
	shape = p_shape

func visual_kind(_self_tile: Tile) -> StringName:
	return &"bomb"

func _do_trigger(_self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if shape == Shape.MANHATTAN:
		return [EffectBombBlast.new(cell, board.cells_within_manhattan_radius(cell, radius))]
	else:
		return [EffectBombBlast.new(cell, board.cells_within_square_radius(cell, radius))]

func can_combine_with_core(other: TriggerCore) -> bool:
	return other is BombCore or other is ArrowBlasterCore or other is PrismCore

func _do_combine_with(other: TriggerCore, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if other is BombCore:
		return _place_and_trigger(Tile.make_bomb(radius + other.radius), cell, board)
	if other is ArrowBlasterCore:
		return _place_and_trigger(Tile.make_arrow_blaster(other.axis, radius + other.extra_lines), cell, board)
	if other is PrismCore:
		return PrismCore.combine_partner_into_majority(self, board)
	return []

func spawn_similar_tile() -> Tile:
	return Tile.make_bomb(radius)
