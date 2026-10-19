## Cell nodes (ground, pit...) kept in line with the board topology.
class_name CellLayer
extends Node3D

static var SCENES_BY_VISUAL_KIND: Dictionary
static var DEFAULT_SCENE: PackedScene

static func _static_init() -> void:
	DEFAULT_SCENE = load(PackPaths.BOARD_PACK + "cell_ground.tscn")
	SCENES_BY_VISUAL_KIND = {
		&"pit": load(PackPaths.BOARD_PACK + "cell_pit.tscn"),
	}

var _nodes: Dictionary = {}  # Vector2i -> Node3D
var _visual_kinds: Dictionary = {}  # Vector2i -> StringName

func build(board: BoardGraph) -> void:
	for cell: GridCell in board.all_cells():
		_add(cell)

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
	var scene: PackedScene = SCENES_BY_VISUAL_KIND.get(cell.kind.visual_kind(), DEFAULT_SCENE)
	var node: Node3D = scene.instantiate()
	node.position = BoardGeometry.cell_to_world(cell.position)
	add_child(node)
	_nodes[cell.position] = node
	_visual_kinds[cell.position] = cell.kind.visual_kind()
