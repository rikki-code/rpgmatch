## Spawns a fresh random-colored tile into an empty cell (top spawner or a
## pit's local refill — the caller decides which cell, this effect doesn't
## care where it came from). Both fields are view hints, in cells:
## - `fall_distance`: how far above its target to start the fall, so it
##   lands at the same time as whatever else is falling in the same batch
##   instead of at a mismatched speed (0 = caller has no better number; the
##   view picks a safe default).
## - `reveal_distance`: how close to its target it must get before the view
##   should actually show it. A tile can need to start well above the
##   segment it's landing in (see EffectGravityColumn) — rendering it for
##   that whole stretch would make it visibly overlap whatever segment
##   happens to occupy that space above (e.g. tiles sitting above a pit).
class_name EffectSpawnTile
extends Effect

var cell: GridCell
var fall_distance: int
var reveal_distance: int

func _init(p_cell: GridCell, p_fall_distance: int = 0, p_reveal_distance: int = 1) -> void:
	cell = p_cell
	fall_distance = p_fall_distance
	reveal_distance = p_reveal_distance

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant != null or not cell.kind.can_hold_tile():
		return []
	var color := board.rng.randi_range(0, board.color_count - 1)
	if board.bomb_spawn_chance > 0.0 and board.rng.randf() < board.bomb_spawn_chance:
		cell.occupant = Tile.make_bomb()
	elif board.color_bomb_spawn_chance > 0.0 and board.rng.randf() < board.color_bomb_spawn_chance:
		cell.occupant = Tile.make_color_bomb(color)
	else:
		cell.occupant = Tile.make_normal(color)
	return []
