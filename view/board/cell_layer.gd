## Cell nodes (ground, pit...) kept in line with the board topology, plus the
## frame and floor around them.
class_name CellLayer
extends Node3D

static var SCENES_BY_VISUAL_KIND: Dictionary
static var DEFAULT_SCENE: PackedScene
static var ALT_SCENE: PackedScene
static var FRAME_SCENE: PackedScene
static var FLOOR_SCENE: PackedScene

static func _static_init() -> void:
	load_packs()

static func load_packs() -> void:
	DEFAULT_SCENE = load(PackPaths.BOARD_PACK + "cell_ground.tscn")
	ALT_SCENE = load(PackPaths.BOARD_PACK + "cell_ground_alt.tscn")
	FRAME_SCENE = load(PackPaths.BOARD_PACK + "board_frame.tscn")
	FLOOR_SCENE = load(PackPaths.BOARD_PACK + "board_floor.tscn")
	SCENES_BY_VISUAL_KIND = {
		&"pit": load(PackPaths.BOARD_PACK + "cell_pit.tscn"),
	}

var _nodes: Dictionary = {}  # Vector2i -> Node3D
var _visual_kinds: Dictionary = {}  # Vector2i -> StringName

func build(board: BoardGraph) -> void:
	var floor_node: Node3D = FLOOR_SCENE.instantiate()
	floor_node.position = Vector3((board.width - 1) * 0.5, 0.0, (board.height - 1) * 0.5)
	add_child(floor_node)
	var frame: BoardDecor = FRAME_SCENE.instantiate()
	add_child(frame)
	frame.fit(board.width, board.height)
	for cell: GridCell in board.all_cells():
		_add(cell)

# Drops everything built from the previous pack; the scenes were reloaded by load_packs().
func reskin(board: BoardGraph) -> void:
	for child in get_children():
		child.queue_free()
	_nodes.clear()
	_visual_kinds.clear()
	build(board)

# The world editor changes topology and cell kinds at runtime, so this reruns after each edit.
func sync(board: BoardGraph) -> void:
	var live: Dictionary = {}  # Vector2i -> true
	for cell: GridCell in board.all_cells():
		live[cell.position] = true
		if not _nodes.has(cell.position):
			_add(cell)
		elif _visual_kinds.get(cell.position) != cell.kind.visual_kind():
			_nodes[cell.position].queue_free()
			_add(cell)
	for pos: Vector2i in _nodes.keys().duplicate():
		if not live.has(pos):
			_nodes[pos].queue_free()
			_nodes.erase(pos)
			_visual_kinds.erase(pos)

func _add(cell: GridCell) -> void:
	# Checkerboard of two stone shades keeps the cells readable.
	var ground := ALT_SCENE if (cell.position.x + cell.position.y) % 2 != 0 else DEFAULT_SCENE
	var scene: PackedScene = SCENES_BY_VISUAL_KIND.get(cell.kind.visual_kind(), ground)
	var node: Node3D = scene.instantiate()
	node.position = BoardGeometry.cell_to_world(cell.position)
	add_child(node)
	_nodes[cell.position] = node
	_visual_kinds[cell.position] = cell.kind.visual_kind()
