class_name GridCell
extends RefCounted

var position: Vector2i
var kind: CellKind
var occupant: BoardEntity
var neighbors: Dictionary = {}  # GridDirection.Dir -> GridCell

func _init(p_position: Vector2i, p_kind: CellKind) -> void:
	position = p_position
	kind = p_kind

func is_empty() -> bool:
	return occupant == null

func neighbor(dir: GridDirection.Dir) -> GridCell:
	return neighbors.get(dir)
