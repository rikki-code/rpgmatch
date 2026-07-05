## Press-drag-release swap: press picks a tile up (BoardView3D lifts it and
## hands its node over to us), dragging slides it toward whichever neighbor
## cell the cursor is heading for while that neighbor's own tile slides the
## opposite way to meet it (a live swap preview), release commits the swap
## in that direction (or springs both back if the drag didn't clear the
## threshold / has no neighbor that way).
class_name InputController
extends Node3D

const DRAG_COMMIT_THRESHOLD := 0.35
const DRAG_LIFT_BONUS := 0.55
const DRAG_FOLLOW_TIME := 0.08

var camera: Camera3D
var board_view: BoardView3D
var board: BoardGraph
var swap_controller: SwapController
var detonate_controller: DetonateController

var _drag_cell: GridCell
var _drag_tile: Tile
var _drag_origin_world: Vector3
var _drag_direction: int = -1
var _drag_fraction: float = 0.0
var _companion_cell: GridCell
var _companion_tile: Tile
var _spring_tweens: Dictionary = {}  # Tile -> Tween
var _editor_active: bool = false

func setup(p_camera: Camera3D, p_board_view: BoardView3D, p_board: BoardGraph, p_swap_controller: SwapController, p_detonate_controller: DetonateController) -> void:
	camera = p_camera
	board_view = p_board_view
	board = p_board
	swap_controller = p_swap_controller
	detonate_controller = p_detonate_controller

func set_editor_active(active: bool) -> void:
	_editor_active = active

func _unhandled_input(event: InputEvent) -> void:
	if _editor_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				_try_detonate(event.position)
			else:
				_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _drag_cell != null:
		_update_drag(event.position)

## Double-click on a bomb blows it up directly instead of starting a drag —
## a separate player action from swapping (see DetonateController).
func _try_detonate(screen_pos: Vector2) -> void:
	if not swap_controller.ctx.awaiting_player_input:
		return
	var cell := board.get_cell(board_view.world_to_cell(_ground_plane_point(screen_pos)))
	if cell == null:
		return
	detonate_controller.try_detonate(cell)

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
	board_view.set_match_preview([])
	board_view.hold(_drag_tile)
	_kill_spring(_drag_tile)
	var node := board_view.node_for_tile(_drag_tile)
	if node != null:
		node.position = board_view.lifted_world(cell.position) + Vector3.UP * DRAG_LIFT_BONUS

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

	# The held tile follows the cursor within a cross/plus shape
	var half_cell := BoardView3D.CELL_SIZE * 0.5 - TileView.RADIUS
	var free_offset := (
		Vector3(clampf(dx, -BoardView3D.CELL_SIZE, BoardView3D.CELL_SIZE), 0.0, clampf(dz, -half_cell, half_cell))
		if horizontal
		else Vector3(clampf(dx, -half_cell, half_cell), 0.0, clampf(dz, -BoardView3D.CELL_SIZE, BoardView3D.CELL_SIZE))
	)
	var drag_target := board_view.lifted_world(_drag_cell.position) + Vector3.UP * DRAG_LIFT_BONUS + free_offset
	_drive(_drag_tile, drag_target, DRAG_FOLLOW_TIME)

	# A combine (see CombineEffectsBehavior) doesn't move either tile onto the
	# other's cell — it's a merge, not a swap — so the companion must not
	# slide out of the way like it would for an ordinary match-swap preview.
	if _companion_tile != null and not _is_combine_candidate():
		var offset_vec := Vector3(offset, 0.0, 0.0) if horizontal else Vector3(0.0, 0.0, offset)
		var companion_target := board_view.lifted_world(_companion_cell.position) - offset_vec
		_drive(_companion_tile, companion_target, DRAG_FOLLOW_TIME)

func _is_combine_candidate() -> bool:
	if _drag_tile == null or _companion_tile == null:
		return false
	return _drag_tile.can_combine_with(_companion_tile) and _companion_tile.can_combine_with(_drag_tile)

## Keeps board_view's "held" set in sync with whichever cell is currently
## the drag target, so the tile living there previews sliding out of the
## way instead of sitting still until the drop.
func _update_companion(neighbor: GridCell) -> void:
	var new_tile: Tile = neighbor.occupant if (neighbor != null and neighbor.occupant is Tile) else null
	if new_tile == _companion_tile:
		_companion_cell = neighbor
		return
	if _companion_tile != null:
		_spring_back(_companion_tile, _companion_cell)
	_companion_tile = new_tile
	_companion_cell = neighbor
	if _companion_tile != null:
		board_view.hold(_companion_tile)
	_update_preview()

func _update_preview() -> void:
	if _companion_cell == null:
		board_view.set_match_preview([])
		return
	if _is_combine_candidate():
		board_view.set_match_preview([_drag_tile, _companion_tile])
		return
	board_view.set_match_preview(swap_controller.preview_match(_drag_cell, _companion_cell))

func _drive(tile: Tile, target: Vector3, duration: float) -> Tween:
	var node := board_view.node_for_tile(tile)
	if node == null:
		return null
	_kill_spring(tile)
	var tween := create_tween()
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_LINEAR)
	_spring_tweens[tile] = tween
	return tween

## Tweens a dropped companion back to its own cell instead of leaving it
## wherever the drag last pushed it (a hard snap there reads as a glitch just
## as much as leaving it mid-air does).
func _spring_back(tile: Tile, cell: GridCell) -> void:
	var node := board_view.node_for_tile(tile)
	if node == null:
		board_view.release(tile)
		return
	var target := board_view.lifted_world(cell.position)
	var tween := _drive(tile, target, DRAG_FOLLOW_TIME)
	if tween == null:
		board_view.release(tile)
		return
	tween.finished.connect(func() -> void:
		if _spring_tweens.get(tile) == tween:
			_spring_tweens.erase(tile)
			if tile != _companion_tile and tile != _drag_tile:
				board_view.release(tile)
	)

func _kill_spring(tile: Tile) -> void:
	var existing: Tween = _spring_tweens.get(tile)
	if existing != null and existing.is_valid():
		existing.kill()
	_spring_tweens.erase(tile)

func _end_drag() -> void:
	if _drag_cell == null:
		return
	var swap_neighbor: GridCell = null
	if absf(_drag_fraction) >= DRAG_COMMIT_THRESHOLD and _drag_direction != -1:
		swap_neighbor = _drag_cell.neighbor(_drag_direction)


	var drag_cell := _drag_cell
	for tile: Tile in _spring_tweens.keys():
		var tween: Tween = _spring_tweens[tile]
		if tween.is_valid():
			tween.kill()
	_spring_tweens.clear()
	board_view.release_all()
	board_view.set_match_preview([])
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
	return BoardView3D.ground_plane_point(camera, screen_pos)
