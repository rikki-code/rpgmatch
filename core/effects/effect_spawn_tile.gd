## Spawns a fresh random-colored tile into an empty cell (top spawner or a
## pit's local refill — the caller decides which cell, this effect doesn't
## care where it came from). See EffectAppearTile for the fall hints.
class_name EffectSpawnTile
extends EffectAppearTile

func _init(p_cell: GridCell, p_fall_distance: int = 0, p_reveal_distance: int = 1) -> void:
	cell = p_cell
	fall_distance = p_fall_distance
	reveal_distance = p_reveal_distance

func execute(board: BoardGraph) -> Array[Effect]:
	if cell.occupant != null or not cell.kind.can_hold_tile():
		return []
	var color := board.random_color()

	if board.arrow_blaster_spawn_chance > 0.0 and board.rng.randf() < board.arrow_blaster_spawn_chance:
		var axis = ArrowBlasterCore.Axis.ROW if board.rng.randi_range(0, 1) == 0 else ArrowBlasterCore.Axis.COLUMN
		cell.occupant = Tile.make_arrow_blaster(axis, 0)
	elif board.bomb_spawn_chance > 0.0 and board.rng.randf() < board.bomb_spawn_chance:
		cell.occupant = Tile.make_bomb()
	elif board.color_bomb_spawn_chance > 0.0 and board.rng.randf() < board.color_bomb_spawn_chance:
		cell.occupant = Tile.make_color_bomb(color)
	elif board.prisms_spawn_chance > 0.0 and board.rng.randf() < board.prisms_spawn_chance:
		cell.occupant = Tile.make_prism()
	else:
		cell.occupant = Tile.make_normal(color)

	tile = cell.occupant
	return []
