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

const CELL_SIZE := GeometryConstants.CELL_SIZE
const TILE_LIFT := 0.35

static var EXPLOSION_SCENE: PackedScene
static var LIGHTNING_SCENE: PackedScene
static var ARROW_BOLT_SCENE: PackedScene
static var CELL_SCENES_BY_VISUAL_KIND: Dictionary
static var DEFAULT_CELL_SCENE: PackedScene

static func _static_init() -> void:
	EXPLOSION_SCENE = load(PackPaths.SPECIAL_TILES_PACK + "tile_explosion.tscn")
	LIGHTNING_SCENE = load(PackPaths.TILES_PACK + "match_lightning.tscn")
	ARROW_BOLT_SCENE = load(PackPaths.SPECIAL_TILES_PACK + "arrow_blast_bolt.tscn")
	DEFAULT_CELL_SCENE = load(PackPaths.BOARD_PACK + "cell_ground.tscn")
	CELL_SCENES_BY_VISUAL_KIND = {
		&"pit": load(PackPaths.BOARD_PACK + "cell_pit.tscn"),
	}

var board: BoardGraph
## Tiles InputController is manually positioning (the dragged tile and, for
## a live swap preview, the neighbor it's sliding toward); refresh() leaves
## these alone instead of tweening them back to their board cell.
var held_tiles: Dictionary = {}  # Tile -> true

var _tile_nodes: Dictionary = {}  # BoardEntity -> Node3D
var _entity_views: Dictionary = {}  # Script -> EntityView
var _entity_tweens: Dictionary = {}  # BoardEntity -> Tween (latest tween driving it)
## Set by refresh() right before it processes an EffectSpawnTile, consumed
## once for that cell — lets a spawned tile start (and stay hidden until)
## exactly as far above its target as the effect says (see
## EffectGravityColumn), instead of every spawn always falling the same
## disproportionate distance or being visible the whole way down.
var _pending_spawn_distance: Dictionary = {}  # GridCell -> {fall: int, reveal: int}

var _preview_entities: Dictionary = {}  # BoardEntity -> true

func setup(p_board: BoardGraph) -> void:
	board = p_board
	_register_entity_views()
	_build_cells()
	_seed_initial_spawn_distances()
	refresh()

## The opening board fill doesn't go through EffectSpawnTile at all —
## BoardGenerator assigns every occupant directly — so without this,
## refresh()'s per-cell lookup always misses and every tile falls the
## generic full-board-height/1-cell-reveal fallback instead of the same
## per-segment "falls from its own nearest border or pit" distances a real
## gravity pass would compute (see EffectGravityColumn._segments/_resolve_segment).
func _seed_initial_spawn_distances() -> void:
	for x in range(board.width):
		var column := board.column_cells_top_to_bottom(x)
		for segment: Array in EffectGravityColumn._segments(column):
			var size: int = segment.size()
			for i in range(size):
				_pending_spawn_distance[segment[i]] = {"fall": size, "reveal": i + 1}

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

## Diffs against the previous call so an already-highlighted tile doesn't restart its pulse.
func set_match_preview(entities: Array) -> void:
	var new_entities: Dictionary = {}  # BoardEntity -> true
	for entity in entities:
		new_entities[entity] = true

	for entity in _preview_entities.keys():
		if not new_entities.has(entity):
			_set_entity_highlighted(entity, false)
	for entity in new_entities.keys():
		if not _preview_entities.has(entity):
			_set_entity_highlighted(entity, true)
	_preview_entities = new_entities

func _set_entity_highlighted(entity: BoardEntity, on: bool) -> void:
	var node: Node3D = _tile_nodes.get(entity)
	var view: EntityView = _view_for(entity)
	if node != null and view != null:
		view.set_highlighted(node, on)

## `effect` is the Effect that was just applied (see game_root's
## effect_applied connection). refresh() only reads it to pick up a spawn's
## fall_distance hint — everything else still comes purely from board state.
func refresh(effect: Effect = null) -> void:
	if effect is EffectSpawnTile and effect.fall_distance > 0:
		_pending_spawn_distance[effect.cell] = {"fall": effect.fall_distance, "reveal": effect.reveal_distance}
	if effect is EffectSpawnBombTile:
		_pending_spawn_distance[effect.cell] = {"fall": effect.fall_distance, "reveal": effect.reveal_distance}
	if effect is EffectSpawnArrowBlasterTile:
		_pending_spawn_distance[effect.cell] = {"fall": effect.fall_distance, "reveal": effect.reveal_distance}
	if effect is EffectBombBlast:
		_play_delayed_explosion(effect.cells)
	if effect is EffectArrowBlast:
		_play_arrow_blast(effect)
	if effect is EffectMatchLightning:
		_play_lightning(effect.cells)

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
			# needs to start (and, separately, how close it must get before
			# it should actually be shown) to land in step with whatever
			# else is falling in the same batch, without being visible while
			# it's still passing through whatever segment happens to sit
			# above this one (see EffectGravityColumn). Without a hint (e.g.
			# the initial board fill has no effect at all), fall the full
			# board height but only reveal for the last cell — always safe.
			var info: Dictionary = _pending_spawn_distance.get(cell, {"fall": board.height, "reveal": 1})
			_pending_spawn_distance.erase(cell)
			var start := cell_to_world(cell.position - Vector2i(0, info.fall)) + Vector3.UP * TILE_LIFT
			var reveal := cell_to_world(cell.position - Vector2i(0, info.reveal)) + Vector3.UP * TILE_LIFT
			_track_tween(entity, view.play_spawn(node, start, reveal, target, self))
		elif not held_tiles.has(entity):
			_track_tween(entity, view.play_move(node, target, self))

## Waits out TileView's fuse-ignite beat so the flash reads as "fuse caught, then boom", not the reverse.
func _play_delayed_explosion(cells: Array) -> void:
	await get_tree().create_timer(TileView.IGNITE_TIME).timeout
	for cell: GridCell in cells:
		_play_explosion(cell.position)

func _play_explosion(cell_position: Vector2i) -> void:
	var node: TileExplosion = EXPLOSION_SCENE.instantiate()
	add_child(node)
	node.position = cell_to_world(cell_position) + Vector3.UP * TILE_LIFT
	node.play()

## Same per-cell flash as a bomb blast, plus a pair of energy bolts shot from
## origin toward both ends of the row/column.
func _play_arrow_blast(effect: EffectArrowBlast) -> void:
	_play_delayed_explosion(effect.cells)
	if effect.cells.is_empty():
		return
	await get_tree().create_timer(TileView.IGNITE_TIME).timeout
	var varies_x := effect.axis == ArrowBlasterCore.Axis.ROW
	var min_pos := effect.origin.position
	var max_pos := effect.origin.position
	for cell: GridCell in effect.cells:
		var coord := cell.position.x if varies_x else cell.position.y
		var min_coord := min_pos.x if varies_x else min_pos.y
		var max_coord := max_pos.x if varies_x else max_pos.y
		if coord < min_coord:
			min_pos = cell.position
		if coord > max_coord:
			max_pos = cell.position
	var origin_world := lifted_world(effect.origin.position)
	_spawn_arrow_bolt(origin_world, lifted_world(min_pos))
	_spawn_arrow_bolt(origin_world, lifted_world(max_pos))

func _spawn_arrow_bolt(from: Vector3, to: Vector3) -> void:
	var node: ArrowBlastBolt = ARROW_BOLT_SCENE.instantiate()
	add_child(node)
	node.play(from, to)

## RIGHT/DOWN only so each adjacent pair draws once, not twice.
func _play_lightning(cells: Array) -> void:
	var in_group: Dictionary = {}  # Vector2i -> true
	for cell: GridCell in cells:
		in_group[cell.position] = true
	for cell: GridCell in cells:
		for dir in [GridDirection.Dir.RIGHT, GridDirection.Dir.DOWN]:
			var neighbor := cell.neighbor(dir)
			if neighbor != null and in_group.has(neighbor.position):
				_spawn_lightning_bolt(lifted_world(cell.position), lifted_world(neighbor.position))

func _spawn_lightning_bolt(from: Vector3, to: Vector3) -> void:
	var node: MatchLightning = LIGHTNING_SCENE.instantiate()
	add_child(node)
	node.play(from, to)

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
		var scene: PackedScene = CELL_SCENES_BY_VISUAL_KIND.get(cell.kind.visual_kind(), DEFAULT_CELL_SCENE)
		var node: Node3D = scene.instantiate()
		node.position = cell_to_world(cell.position)
		add_child(node)
