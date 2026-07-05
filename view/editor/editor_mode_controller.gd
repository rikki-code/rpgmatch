## R-key toggle for the world editor. Owns which tool is active (place a
## cell kind / remove-cell / place-a-catalog-tile — mutually exclusive) and
## turns a board click into a BoardEditController call. toggle() is separate
## from the key handler so a future menu entry point can call it directly.
## Only enters/leaves while the turn manager is parked waiting for player
## input — on leaving, kicks the turn cycle (see PhasePhysicsResolve) so
## whatever edits left behind (empty cells, accidental matches) get settled
## by the normal gravity/match machinery instead of a bespoke editor version.
class_name EditorModeController
extends Node3D

signal mode_changed(active: bool)

enum ToolKind { SET_CELL_KIND, REMOVE_CELL, PLACE_TILE }

var camera: Camera3D
var board_view: BoardView3D
var ctx: TurnContext
var edit_controller: BoardEditController
var tile_catalog: Array[EditorTileCatalog.Entry] = []
var cell_catalog: Array[EditorCellCatalog.Entry] = []

var active: bool = false
var _tool_kind: ToolKind = ToolKind.SET_CELL_KIND
var _active_cell_entry: EditorCellCatalog.Entry
var _active_tile_entry: EditorTileCatalog.Entry

func setup(p_camera: Camera3D, p_board_view: BoardView3D, p_ctx: TurnContext) -> void:
	camera = p_camera
	board_view = p_board_view
	ctx = p_ctx
	edit_controller = BoardEditController.new(ctx)
	tile_catalog = EditorTileCatalog.build(ctx.board)
	cell_catalog = EditorCellCatalog.build()
	_active_cell_entry = cell_catalog[0]

func toggle() -> void:
	if not active and not ctx.awaiting_player_input:
		return
	active = not active
	if not active:
		ctx.board.link_grid_neighbors()
		board_view.sync_cells()
		board_view.refresh(null, true)
		ctx.turn_manager.notify_phase_done()
	mode_changed.emit(active)

func select_cell_kind(entry: EditorCellCatalog.Entry) -> void:
	_tool_kind = ToolKind.SET_CELL_KIND
	_active_cell_entry = entry

func select_remove_cell() -> void:
	_tool_kind = ToolKind.REMOVE_CELL

func select_tile(entry: EditorTileCatalog.Entry) -> void:
	_tool_kind = ToolKind.PLACE_TILE
	_active_tile_entry = entry

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(screen_pos: Vector2) -> void:
	var pos := board_view.world_to_cell(BoardView3D.ground_plane_point(camera, screen_pos))
	match _tool_kind:
		ToolKind.SET_CELL_KIND:
			edit_controller.set_cell_kind(pos, _active_cell_entry.factory)
			board_view.sync_cells()
			board_view.refresh(null, true)
		ToolKind.REMOVE_CELL:
			edit_controller.remove_cell(pos)
			board_view.sync_cells()
			board_view.refresh(null, true)
		ToolKind.PLACE_TILE:
			if _active_tile_entry == null:
				return
			if _active_tile_entry.factory.is_valid():
				edit_controller.place_tile(pos, _active_tile_entry.factory)
			else:
				edit_controller.clear_tile(pos)
			board_view.refresh(null, true)
