## Direct BoardGraph mutations for the world editor (view/editor/). Bypasses
## the turn/effect pipeline entirely — same as BoardGenerator/BoardLayout
## assigning occupants straight onto cells — since editor edits aren't a
## gameplay action to animate or resolve, just authoring. Refuses to mutate
## unless ctx.awaiting_player_input — otherwise a click could land mid-
## cascade (matches still resolving, tiles still falling) and desync the
## view from a board the effect pipeline is also mutating concurrently.
class_name BoardEditController
extends RefCounted

var ctx: TurnContext
var board: BoardGraph

func _init(p_ctx: TurnContext) -> void:
	ctx = p_ctx
	board = p_ctx.board

## Places a cell of the given kind, or re-kinds one that's already there
## (e.g. normal -> pit). Re-kinding to something that can't hold a tile
## drops the occupant — same "editor overwrites silently" rule as place_tile.
func set_cell_kind(pos: Vector2i, kind_factory: Callable) -> void:
	if not ctx.awaiting_player_input:
		return
	if pos.x < 0 or pos.x >= board.width or pos.y < 0 or pos.y >= board.height:
		return
	var cell := board.get_cell(pos)
	if cell == null:
		board.add_cell(GridCell.new(pos, kind_factory.call()))
		board.link_grid_neighbors()
		return
	cell.kind = kind_factory.call()
	if not cell.kind.can_hold_tile():
		cell.occupant = null

func remove_cell(pos: Vector2i) -> void:
	if not ctx.awaiting_player_input:
		return
	if board.get_cell(pos) == null:
		return
	board.remove_cell(pos)

func place_tile(pos: Vector2i, factory: Callable) -> void:
	if not ctx.awaiting_player_input:
		return
	var cell := board.get_cell(pos)
	if cell == null or not cell.kind.can_hold_tile():
		return
	cell.occupant = factory.call()

func clear_tile(pos: Vector2i) -> void:
	if not ctx.awaiting_player_input:
		return
	var cell := board.get_cell(pos)
	if cell == null:
		return
	cell.occupant = null
