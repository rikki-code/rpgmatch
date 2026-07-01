## A tile is generic: color + a list of TileBehavior. Bonus/penalty tiles
## are the same class with a different behavior list, not subclasses.
class_name Tile
extends BoardEntity

var color: int
var behaviors: Array[TileBehavior] = []

func _init(p_color: int = 0) -> void:
	color = p_color

func display_name() -> String:
	return "tile(color=%d)" % color

func can_match_with(other: BoardEntity) -> bool:
	if not (other is Tile):
		return false
	for behavior in behaviors:
		if behavior.can_match_with(self, other):
			return true
	return false

func blocks_swap() -> bool:
	for behavior in behaviors:
		if behavior.blocks_swap(self):
			return true
	return false

func on_matched(cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_matched(self, cell, board))
	return effects

func on_turn_tick(cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_turn_tick(self, cell, board))
	return effects

func on_damage(amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_damage(self, amount, cell, board))
	return effects
