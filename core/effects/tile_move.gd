## One tile pulled from `from` to `to` by gravity.
class_name TileMove
extends RefCounted

var entity: BoardEntity
var from: GridCell
var to: GridCell

func _init(p_entity: BoardEntity, p_from: GridCell, p_to: GridCell) -> void:
	entity = p_entity
	from = p_from
	to = p_to
