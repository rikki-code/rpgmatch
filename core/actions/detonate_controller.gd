## Handles a player's direct-activation input on a tile (currently: double-
## click a bomb to blow it up on demand) — not a swap, just another way a
## player's turn can end. Calls Tile.detonate (a separate hook from
## on_damage — see TileBehavior.detonate) so this always works regardless of
## whether on_damage is currently gated to something else (e.g. a bomb's
## splash-triggered explosion requires it was just swapped into a match —
## see BombBehavior); nothing here knows what a bomb is.
class_name DetonateController
extends RefCounted

signal detonated(cell: GridCell)

var ctx: TurnContext

func _init(p_ctx: TurnContext) -> void:
	ctx = p_ctx

func try_detonate(cell: GridCell) -> bool:
	if not ctx.awaiting_player_input:
		return false
	if not (cell.occupant is Tile):
		return false
	var tile: Tile = cell.occupant
	if not tile.is_manually_detonatable():
		return false

	ctx.resolver.resolve(tile.detonate(cell, ctx.board))
	detonated.emit(cell)
	await ctx.animation_driver.await_settle()
	ctx.turn_manager.notify_phase_done()
	return true
