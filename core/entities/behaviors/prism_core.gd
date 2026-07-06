## Prism's own blast shape on top of TriggerCore's shared "one detonation,
## several triggers" plumbing (`_triggered` guard, on_damage wiring — see
## TriggerCore). Unlike Bomb/Arrow's fixed radius/line, its target set is
## computed live from board state: whichever color currently has the most
## tiles on the board takes the hit, wherever those tiles are.
##
## Combining two prisms skips color targeting entirely and hits every
## occupied cell. Combining with any other bonus tile is asymmetric — it
## doesn't produce a single merged tile at the swap destination like
## Bomb+Arrow does. Instead it seeds a fresh copy of the *partner's* own kind
## onto every majority-color cell and detonates each one on the spot (see
## combine_partner_into_majority) — a barrage of the other tile's effect,
## fanned out by color. Bomb/ArrowBlasterCore each carry a matching
## `if other is PrismCore` branch (see bomb_core.gd/arrow_blaster_core.gd) so
## the recipe fires the same way regardless of which tile the player dragged.
class_name PrismCore
extends TriggerCore

func visual_kind(_self_tile: Tile) -> StringName:
	return &"prism"

func spawn_similar_tile() -> Tile:
	return Tile.make_prism()

func can_combine_with_core(_other: TriggerCore) -> bool:
	return true

func _do_trigger(_self_tile: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var color := _dominant_color(board)
	return [EffectPrismBlast.new(cell, _cells_with_color(board, color), color)]

func _do_combine_with(other: TriggerCore, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	if other is PrismCore:
		return [EffectPrismBlast.new(cell, _all_occupied_cells(board))]
	return combine_partner_into_majority(other, board)

static func combine_partner_into_majority(partner_core: TriggerCore, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for target_cell in _cells_with_color(board, _dominant_color(board)):
		var fresh := partner_core.spawn_similar_tile()
		if fresh == null:
			continue
		effects.append_array(_place_and_trigger(fresh, target_cell, board))
	return effects

static func _dominant_color(board: BoardGraph) -> int:
	var counts: Dictionary = {}
	for cell: GridCell in board.all_cells():
		var occupant := cell.occupant
		if occupant is Tile and occupant.color >= 0:
			counts[occupant.color] = counts.get(occupant.color, 0) + 1
	var best_color := 0
	var best_count := -1
	for color: int in counts:
		if counts[color] > best_count:
			best_count = counts[color]
			best_color = color
	return best_color

static func _cells_with_color(board: BoardGraph, color: int) -> Array[GridCell]:
	var cells: Array[GridCell] = []
	for cell: GridCell in board.all_cells():
		if cell.occupant is Tile and (cell.occupant as Tile).color == color:
			cells.append(cell)
	return cells

static func _all_occupied_cells(board: BoardGraph) -> Array[GridCell]:
	var cells: Array[GridCell] = []
	for cell: GridCell in board.all_cells():
		if cell.occupant is Tile:
			cells.append(cell)
	return cells
