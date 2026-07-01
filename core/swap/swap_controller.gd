## Validates and performs a player swap: must be graph-adjacent (works for
## any topology, not just a rectangular grid), both cells must hold tiles
## that don't block swapping, and the swap must create a match — otherwise
## it's reverted. Only accepted while the turn manager is in the player
## input phase. Waits for ctx.animation_driver to settle (the swap-glide
## finishing) before handing the turn to PhasePhysicsResolve, so the match
## doesn't get destroyed before the swap that created it is even shown.
class_name SwapController
extends RefCounted

signal swap_applied(cell_a: GridCell, cell_b: GridCell)
signal swap_rejected(cell_a: GridCell, cell_b: GridCell)

var ctx: TurnContext

func _init(p_ctx: TurnContext) -> void:
	ctx = p_ctx

func try_swap(cell_a: GridCell, cell_b: GridCell) -> bool:
	if not ctx.awaiting_player_input:
		return false
	if not cell_a.neighbors.values().has(cell_b):
		return false
	if not (cell_a.occupant is Tile) or not (cell_b.occupant is Tile):
		return false

	var tile_a: Tile = cell_a.occupant
	var tile_b: Tile = cell_b.occupant
	if tile_a.blocks_swap() or tile_b.blocks_swap():
		return false

	ctx.board.swap_occupants(cell_a, cell_b)

	var creates_match := false
	for group in MatchFinder.find_matches(ctx.board):
		if group.cells.has(cell_a) or group.cells.has(cell_b):
			creates_match = true
			break

	if not creates_match:
		ctx.board.swap_occupants(cell_a, cell_b)
		swap_rejected.emit(cell_a, cell_b)
		return false

	swap_applied.emit(cell_a, cell_b)
	await ctx.animation_driver.await_settle()
	ctx.turn_manager.notify_phase_done()
	return true
