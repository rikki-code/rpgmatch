## Validates and performs a player swap: must be graph-adjacent (works for
## any topology, not just a rectangular grid), both cells must hold tiles
## that don't block swapping, and either the two tiles combine (see
## CombineEffectsBehavior — takes priority, no match required) or the swap
## must create a match — otherwise it's reverted. Only accepted while the
## turn manager is in the player input phase. Waits for
## ctx.animation_driver to settle (the swap-glide finishing) before handing
## the turn to PhasePhysicsResolve, so the match doesn't get destroyed
## before the swap that created it is even shown.
class_name SwapController
extends RefCounted

signal swap_applied(cell_a: GridCell, cell_b: GridCell)
signal swap_rejected(cell_a: GridCell, cell_b: GridCell)
signal tiles_combined(cell_a: GridCell, cell_b: GridCell)

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

	# Two combinable bonus tiles (e.g. bomb+arrow blaster) always take
	# priority over the ordinary match rule below — merging them doesn't need
	# a resulting match, see CombineEffectsBehavior/TriggerCore.do_combine_with.
	if tile_a.can_combine_with(tile_b) and tile_b.can_combine_with(tile_a):
		cell_a.occupant = null
		cell_b.occupant = null
		ctx.resolver.resolve(tile_a.combine_with(tile_b, cell_b, ctx.board))
		tiles_combined.emit(cell_a, cell_b)
		await ctx.animation_driver.await_settle()
		ctx.turn_manager.notify_phase_done()
		return true

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

	ctx.board.swapped_tiles = [tile_a, tile_b]
	swap_applied.emit(cell_a, cell_b)
	await ctx.animation_driver.await_settle()
	ctx.turn_manager.notify_phase_done()
	return true

## Non-mutating: Tiles that would end up matched if cell_a/cell_b swapped now
## (empty if not). Read while swapped, before reverting — reverted state would
## report the pre-swap occupants instead of who'd actually be there.
func preview_match(cell_a: GridCell, cell_b: GridCell) -> Array[Tile]:
	var empty: Array[Tile] = []
	if not (cell_a.occupant is Tile) or not (cell_b.occupant is Tile):
		return empty
	var tile_a: Tile = cell_a.occupant
	var tile_b: Tile = cell_b.occupant
	if tile_a.blocks_swap() or tile_b.blocks_swap():
		return empty

	ctx.board.swap_occupants(cell_a, cell_b)
	var result: Array[Tile] = []
	for group in MatchFinder.find_matches(ctx.board):
		if group.cells.has(cell_a) or group.cells.has(cell_b):
			for cell: GridCell in group.cells:
				var occupant_tile: Tile = cell.occupant
				result.append(occupant_tile)
	ctx.board.swap_occupants(cell_a, cell_b)
	return result
