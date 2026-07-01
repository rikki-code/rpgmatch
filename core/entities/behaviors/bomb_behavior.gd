## Bonus tile: explodes in a diamond (Manhattan-distance) blast radius when
## matched (e.g. caught in another bomb's blast, see EffectBombBlast),
## manually detonated (see DetonateController), or damaged by splash from a
## neighboring match — but that last route only counts if this bomb was
## itself one of the two tiles just swapped into that match (see
## BoardGraph.swapped_tiles); an incidental match happening to sit next to
## an otherwise-untouched bomb should not set it off. All routes funnel into
## the same _trigger(). `radius` is a plain instance field, not a const, so
## a stronger bomb variant is just a subclass overriding the default in
## _init() (e.g. `BigBombBehavior extends BombBehavior` with radius 2).
class_name BombBehavior
extends TileBehavior

var radius: int
var _exploded := false
var _manually_detonatable: bool = true

func _init(p_radius: int = 1, manually_detonatable: bool = true) -> void:
	radius = p_radius
	_manually_detonatable = manually_detonatable

func on_matched(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return _trigger(self_tile, cell, board)

func on_damage(self_tile: Tile, _amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if not board.swapped_tiles.has(self_tile):
		return []
	return _trigger(self_tile, cell, board)

func detonate(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	return _trigger(self_tile, cell, board)

func is_manually_detonatable(_self_tile: Tile) -> bool:
	return _manually_detonatable

func visual_kind(_self_tile: Tile) -> StringName:
	return &"bomb"

func _trigger(self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if _exploded:
		return []
	_exploded = true
	if cell.occupant == self_tile:
		cell.occupant = null
	return [EffectBombBlast.new(cell, board.cells_within_manhattan_radius(cell, radius))]
