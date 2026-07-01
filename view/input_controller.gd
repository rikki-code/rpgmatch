## Press-drag-release swap: press picks a tile up (BoardView3D lifts it and
## hands its node over to us), dragging slides it toward whichever neighbor
## cell the cursor is heading for while that neighbor's own tile slides the
## opposite way to meet it (a live swap preview), release commits the swap
## in that direction (or springs both back if the drag didn't clear the
## threshold / has no neighbor that way).
class_name InputController
extends Node3D

const DRAG_COMMIT_THRESHOLD := 0.35

var camera: Camera3D
var board_view: BoardView3D
var board: BoardGraph
var swap_controller: SwapController

var _drag_cell: GridCell
var _drag_tile: Tile
var _drag_origin_world: Vector3
var _drag_direction: int = -1
var _drag_fraction: float = 0.0
var _companion_cell: GridCell
var _companion_tile: Tile

func setup(p_camera: Camera3D, p_board_view: BoardView3D, p_board: BoardGraph, p_swap_controller: SwapController) -> void:
	camera = p_camera
	board_view = p_board_view
	board = p_board
	swap_controller = p_swap_controller

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _drag_cell != null:
		_update_drag(event.position)

func _begin_drag(screen_pos: Vector2) -> void:
	if not swap_controller.ctx.awaiting_player_input:
		return
	var cell := board.get_cell(board_view.world_to_cell(_ground_plane_point(screen_pos)))
	if cell == null or not (cell.occupant is Tile):
		return
	_drag_cell = cell
	_drag_tile = cell.occupant
	_drag_origin_world = board_view.cell_to_world(cell.position)
	_drag_direction = -1
	_drag_fraction = 0.0
	_companion_cell = null
	_companion_tile = null
	board_view.hold(_drag_tile)

func _update_drag(screen_pos: Vector2) -> void:
	var world_pos := _ground_plane_point(screen_pos)
	var dx := world_pos.x - _drag_origin_world.x
	var dz := world_pos.z - _drag_origin_world.z
	var horizontal := absf(dx) >= absf(dz)
	var direction: int = (
		(GridDirection.Dir.RIGHT if dx > 0 else GridDirection.Dir.LEFT) if horizontal
		else (GridDirection.Dir.DOWN if dz > 0 else GridDirection.Dir.UP)
	)

	var neighbor := _drag_cell.neighbor(direction)
	var offset := 0.0
	if neighbor != null:
		offset = clampf(dx if horizontal else dz, -BoardView3D.CELL_SIZE, BoardView3D.CELL_SIZE)
		_drag_direction = direction
		_drag_fraction = offset / BoardView3D.CELL_SIZE
	else:
		_drag_direction = -1
		_drag_fraction = 0.0

	_update_companion(neighbor if _drag_direction != -1 else null)

	var offset_vec := Vector3(offset, 0.0, 0.0) if horizontal else Vector3(0.0, 0.0, offset)
	var dragged_node := board_view.node_for_tile(_drag_tile)
	if dragged_node != null:
		dragged_node.position = board_view.lifted_world(_drag_cell.position) + offset_vec

	if _companion_tile != null:
		var companion_node := board_view.node_for_tile(_companion_tile)
		if companion_node != null:
			companion_node.position = board_view.lifted_world(_companion_cell.position) - offset_vec

## Keeps board_view's "held" set in sync with whichever cell is currently
## the drag target, so the tile living there previews sliding out of the
## way instead of sitting still until the drop.
func _update_companion(neighbor: GridCell) -> void:
	var new_tile: Tile = neighbor.occupant if (neighbor != null and neighbor.occupant is Tile) else null
	if new_tile == _companion_tile:
		_companion_cell = neighbor
		return
	if _companion_tile != null:
		board_view.release(_companion_tile)
	_companion_tile = new_tile
	_companion_cell = neighbor
	if _companion_tile != null:
		board_view.hold(_companion_tile)

func _end_drag() -> void:
	if _drag_cell == null:
		return
	var swap_neighbor: GridCell = null
	if absf(_drag_fraction) >= DRAG_COMMIT_THRESHOLD and _drag_direction != -1:
		swap_neighbor = _drag_cell.neighbor(_drag_direction)


	var drag_cell := _drag_cell
	board_view.release_all()
	if swap_neighbor != null:
		swap_controller.try_swap(drag_cell, swap_neighbor)

	board_view.refresh()
	_drag_cell = null
	_drag_tile = null
	_drag_direction = -1
	_drag_fraction = 0.0
	_companion_cell = null
	_companion_tile = null

func _ground_plane_point(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var denom := dir.y if absf(dir.y) > 0.0001 else 0.0001
	var t := -from.y / denom
	return from + dir * t
