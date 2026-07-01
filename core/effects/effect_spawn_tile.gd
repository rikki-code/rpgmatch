## Spawns a fresh random-colored tile into an empty cell (top spawner or a
## pit's local refill — the caller decides which cell, this effect doesn't
## care where it came from). `fall_distance` is a view hint: how many cells
## "above" this one to start the fall from, so it lands at the same time as
## whatever else is falling in the same batch instead of at a mismatched
## speed (0 = caller has no better number; the view picks a safe default).
class_name EffectSpawnTile
extends Effect

var cell: GridCell
var fall_distance: int

func _init(p_cell: GridCell, p_fall_distance: int = 0) -> void:
	cell = p_cell
	fall_distance = p_fall_distance

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant != null or not cell.kind.can_hold_tile():
		return []
	var tile := Tile.new(board.rng.randi_range(0, board.color_count - 1))
	tile.behaviors.append(ColorBehavior.new())
	cell.occupant = tile
	return []
