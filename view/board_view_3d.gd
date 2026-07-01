## Top-down 3D rendering of a BoardGraph. Purely reactive: builds/refreshes
## nodes from board state, decides nothing about gameplay and nothing about
## how a given entity type looks or animates (that's EntityView/TileView).
## Nodes are keyed by BoardEntity identity, not by cell, so an entity that
## moved keeps its mesh instead of popping a new one. Tracks every in-flight
## tween so PhasePhysicsResolve can await await_settled() between world-cycle
## waves instead of the whole cascade landing before any of it is shown.
class_name BoardView3D
extends Node3D

signal settled

const CELL_SIZE := 1.0
const TILE_LIFT := 0.35

var board: BoardGraph
## Tiles InputController is manually positioning (the dragged tile and, for
## a live swap preview, the neighbor it's sliding toward); refresh() leaves
## these alone instead of tweening them back to their board cell.
var held_tiles: Dictionary = {}  # Tile -> true

var _tile_nodes: Dictionary = {}  # BoardEntity -> Node3D
var _entity_views: Dictionary = {}  # Script -> EntityView
var _entity_tweens: Dictionary = {}  # BoardEntity -> Tween (latest tween driving it)
## Set by refresh() right before it processes an EffectSpawnTile, consumed
## once for that cell — lets a spawned tile start its fall exactly as far
## above its target as the effect says (see EffectGravityColumn), instead
## of every spawn always falling the same disproportionate distance.
var _pending_spawn_distance: Dictionary = {}  # GridCell -> int

func setup(p_board: BoardGraph) -> void:
	board = p_board
	_register_entity_views()
	_build_cells()
	refresh()

## New BoardEntity subtype (rock, enemy...) registers its EntityView here —
## not a new branch in refresh().
func _register_entity_views() -> void:
	_entity_views[Tile] = TileView.new()

func _view_for(entity: BoardEntity) -> EntityView:
	var found: Variant = _entity_views.get(entity.get_script())
	return found as EntityView

## Resolves once no tween started by this view is still in flight.
func await_settled() -> void:
	if _entity_tweens.is_empty():
		return
	await settled

func cell_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))

func lifted_world(pos: Vector2i) -> Vector3:
	return cell_to_world(pos) + Vector3.UP * TILE_LIFT

func node_for_cell(cell: GridCell) -> Node3D:
	if cell.occupant == null:
		return null
	return _tile_nodes.get(cell.occupant)

func node_for_tile(tile: Tile) -> Node3D:
	return _tile_nodes.get(tile)

func hold(tile: Tile) -> void:
	held_tiles[tile] = true

func release(tile: Tile) -> void:
	held_tiles.erase(tile)

func release_all() -> void:
	held_tiles.clear()

## `effect` is the Effect that was just applied (see game_root's
## effect_applied connection). refresh() only reads it to pick up a spawn's
## fall_distance hint — everything else still comes purely from board state.
func refresh(effect: Effect = null) -> void:
	if effect is EffectSpawnTile and effect.fall_distance > 0:
		_pending_spawn_distance[effect.cell] = effect.fall_distance

	var live_entities: Dictionary = {}  # BoardEntity -> GridCell
	for cell: GridCell in board.all_cells():
		if cell.occupant != null:
			live_entities[cell.occupant] = cell

	for entity in _tile_nodes.keys().duplicate():
		if not live_entities.has(entity):
			_play_destroy(entity)

	for entity: BoardEntity in live_entities.keys():
		var view: EntityView = _view_for(entity)
		if view == null:
			continue
		var cell: GridCell = live_entities[entity]
		var target := cell_to_world(cell.position) + Vector3.UP * TILE_LIFT
		var node: Node3D = _tile_nodes.get(entity)
		if node == null:
			node = view.build_node(entity)
			add_child(node)
			_tile_nodes[entity] = node
			# The effect tells us exactly how far above its target this tile
			# needs to start to land in step with whatever else is falling
			# in the same batch (see EffectGravityColumn). Without that hint
			# (e.g. the initial board fill has no effect at all), fall the
			# full board height, so it still reads as coming from an
			# invisible extension above the board rather than popping in.
			var fall_distance: int = _pending_spawn_distance.get(cell, board.height)
			_pending_spawn_distance.erase(cell)
			var start_pos := cell.position - Vector2i(0, fall_distance)
			var start := cell_to_world(start_pos) + Vector3.UP * TILE_LIFT
			_track_tween(entity, view.play_spawn(node, start, target, self))
		elif not held_tiles.has(entity):
			_track_tween(entity, view.play_move(node, target, self))

func _play_destroy(entity: BoardEntity) -> void:
	var node: Node3D = _tile_nodes[entity]
	_tile_nodes.erase(entity)
	var view := _view_for(entity)
	if view == null:
		node.queue_free()
		return
	_track_tween(entity, view.play_destroy(node, self, node.queue_free))

## Kills whatever tween was previously driving this entity (so two tweens
## never fight over the same node's position/scale) and starts tracking the
## new one for await_settled()/settled.
func _track_tween(entity: BoardEntity, tween: Tween) -> void:
	var existing: Tween = _entity_tweens.get(entity)
	if existing != null and existing.is_valid():
		existing.kill()
	if tween == null:
		_entity_tweens.erase(entity)
		return
	_entity_tweens[entity] = tween
	tween.finished.connect(_on_tween_finished.bind(entity, tween))

func _on_tween_finished(entity: BoardEntity, tween: Tween) -> void:
	if _entity_tweens.get(entity) == tween:
		_entity_tweens.erase(entity)
	if _entity_tweens.is_empty():
		settled.emit()

func _build_cells() -> void:
	for cell: GridCell in board.all_cells():
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(CELL_SIZE * 0.94, 0.2, CELL_SIZE * 0.94)
		node.mesh = box
		var material := StandardMaterial3D.new()
		material.roughness = 0.85
		material.albedo_color = Color(0.55, 0.57, 0.62) if cell.kind.can_hold_tile() else Color(0.03, 0.03, 0.05)
		node.material_override = material
		node.position = cell_to_world(cell.position)
		add_child(node)
