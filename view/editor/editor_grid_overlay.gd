## Translucent marker over every board coordinate (including empty ones, so
## an add-cell click has something to aim at), visible only while the world
## editor is active. Built once from board.width/height, which don't change
## at runtime — only which coordinates hold a GridCell does.
class_name EditorGridOverlay
extends Node3D

const CELL_SIZE := GeometryConstants.CELL_SIZE
const MARKER_HEIGHT := 0.12

static var MARKER_SCENE: PackedScene

static func _static_init() -> void:
	MARKER_SCENE = load("res://view/editor/editor_grid_cell.tscn")

func setup(board: BoardGraph) -> void:
	for y in range(board.height):
		for x in range(board.width):
			var node: Node3D = MARKER_SCENE.instantiate()
			node.position = Vector3(x * CELL_SIZE, MARKER_HEIGHT, y * CELL_SIZE)
			add_child(node)
	visible = false

func set_active(active: bool) -> void:
	visible = active
