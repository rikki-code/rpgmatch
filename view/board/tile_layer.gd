## Tile nodes of the board, one per entity: created, moved and released as the
## board changes. Entity-specific look lives in EntityView, motion in TileMotion.
class_name TileLayer
extends Node3D

var board: BoardGraph

var _tracker: ActivityTracker
var _motion: TileMotion
var _views: Dictionary = {}  # Script -> EntityView
var _nodes: Dictionary = {}  # BoardEntity -> Node3D
var _dying: Dictionary = {}  # BoardEntity -> Tween
var _held: Dictionary = {}  # Tile -> true
var _preview: Dictionary = {}  # BoardEntity -> true

func setup(p_board: BoardGraph, tracker: ActivityTracker) -> void:
	board = p_board
	_tracker = tracker
	_motion = TileMotion.new(self, tracker)
	# A new BoardEntity subtype (rock, enemy...) registers its EntityView here.
	_views[Tile] = TileView.new()

func spawn(entity: BoardEntity, cell: GridCell, fall: int, reveal: int) -> Tween:
	var view := _view_for(entity)
	if view == null:
		return null
	var node := _ensure_node(entity, view)
	if fall <= 0:
		node.position = BoardGeometry.lifted_world(cell.position)
		return _motion.pop(node)
	var reveal_z := BoardGeometry.lifted_world(cell.position - Vector2i(0, reveal)).z if reveal < fall else NAN
	return _motion.fall(node, BoardGeometry.lifted_world(cell.position - Vector2i(0, fall)), BoardGeometry.lifted_world(cell.position), reveal_z)

func move(entity: BoardEntity, to: GridCell) -> Tween:
	var node: Node3D = _nodes.get(entity)
	if node == null:
		return null
	return _motion.fall(node, node.position, BoardGeometry.lifted_world(to.position))

# The node stops being tracked at once, so nothing else touches it while it plays out.
func destroy(entity: BoardEntity) -> void:
	var node: Node3D = _nodes.get(entity)
	if node == null:
		return
	_nodes.erase(entity)
	var view := _view_for(entity)
	var tween := view.play_destroy(node, self, view.release_node.bind(node)) if view != null else null
	if tween == null:
		_release(entity, node)
		return
	_motion.adopt(node, tween)
	_dying[entity] = tween
	tween.finished.connect(_on_dying_finished.bind(entity))

# A detonating tile's fuse (its destroy animation) must end before its blast.
func fuse_finished(source: Tile) -> void:
	if source != null and _dying.has(source):
		await _tracker.wait(_dying[source])

func wobble(cell: GridCell) -> void:
	var node := node_for_cell(cell)
	if node != null:
		_motion.wobble(node)

# Brings nodes in line with the board; `instant` snaps instead of animating.
func refresh(instant: bool = false) -> void:
	var live: Dictionary = {}  # BoardEntity -> GridCell
	for cell: GridCell in board.all_cells():
		if cell.occupant != null:
			live[cell.occupant] = cell

	for entity in _nodes.keys().duplicate():
		if live.has(entity):
			continue
		if instant:
			var node: Node3D = _nodes[entity]
			_nodes.erase(entity)
			_motion.stop(node)
			_release(entity, node)
		else:
			destroy(entity)

	for entity: BoardEntity in live.keys():
		var view := _view_for(entity)
		if view == null:
			continue
		var cell: GridCell = live[entity]
		var target := BoardGeometry.lifted_world(cell.position)
		var node: Node3D = _nodes.get(entity)
		if node == null:
			if instant:
				node = _ensure_node(entity, view)
				node.position = target
				node.visible = true
			else:
				var drop := _segment_drop(cell)
				spawn(entity, cell, drop.x, drop.y)
		elif instant:
			_motion.stop(node)
			node.position = target
			node.scale = Vector3.ONE
			node.visible = true
		elif not _held.has(entity) and node.position.distance_squared_to(target) > 0.0001:
			_motion.slide(node, target)

# Rebuilds every live node from the freshly loaded pack, keeping where it stands.
# Only valid while no tween runs on the nodes (BoardView3D.reskin waits for idle).
func reskin() -> void:
	for script: Script in _views.keys():
		var view: EntityView = _views[script]
		view.dispose()
		_views[script] = view.get_script().new()
	for entity: BoardEntity in _nodes.keys():
		var old: Node3D = _nodes[entity]
		var node := _view_for(entity).build_node(entity)
		add_child(node)
		node.position = old.position
		node.scale = old.scale
		node.visible = old.visible
		_nodes[entity] = node
		old.queue_free()
	for entity: BoardEntity in _preview.keys():
		_highlight(entity, true)

func node_for_cell(cell: GridCell) -> Node3D:
	return _nodes.get(cell.occupant) if cell.occupant != null else null

func node_for_tile(tile: Tile) -> Node3D:
	return _nodes.get(tile)

# Held tiles are positioned by the input controller; refresh leaves them alone.
func hold(tile: Tile) -> void:
	_held[tile] = true

func release(tile: Tile) -> void:
	_held.erase(tile)

func release_all() -> void:
	_held.clear()

# Diffs against the previous call so an already-highlighted tile doesn't restart its pulse.
func set_match_preview(entities: Array) -> void:
	var next: Dictionary = {}  # BoardEntity -> true
	for entity in entities:
		next[entity] = true
	for entity in _preview.keys():
		if not next.has(entity):
			_highlight(entity, false)
	for entity in next.keys():
		if not _preview.has(entity):
			_highlight(entity, true)
	_preview = next

func _highlight(entity: BoardEntity, on: bool) -> void:
	var node: Node3D = _nodes.get(entity)
	var view := _view_for(entity)
	if node != null and view != null:
		view.set_highlighted(node, on)

func _view_for(entity: BoardEntity) -> EntityView:
	return _views.get(entity.get_script()) as EntityView

func _ensure_node(entity: BoardEntity, view: EntityView) -> Node3D:
	var node: Node3D = _nodes.get(entity)
	if node == null:
		node = view.build_node(entity)
		if node.get_parent() == null:
			add_child(node)
		_nodes[entity] = node
	return node

func _release(entity: BoardEntity, node: Node3D) -> void:
	var view := _view_for(entity)
	if view != null:
		view.release_node(node)
	else:
		node.queue_free()

# Opening fill: the fall a gravity pass would give a tile in this cell's segment.
func _segment_drop(cell: GridCell) -> Vector2i:
	for segment: Array in EffectGravityColumn._segments(board.column_cells_top_to_bottom(cell.position.x)):
		var index := segment.find(cell)
		if index >= 0:
			return Vector2i(segment.size(), index + 1)
	return Vector2i(board.height, 1)

func _on_dying_finished(entity: BoardEntity) -> void:
	_dying.erase(entity)
