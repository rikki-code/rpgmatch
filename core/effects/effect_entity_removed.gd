## Marks a tile removed outside EffectDestroyTile (self-detonation, see
## TriggerCore.trigger) so score/quest listeners see it the same way.
class_name EffectEntityRemoved
extends Effect

var entity: BoardEntity
var cell: GridCell

func _init(p_entity: BoardEntity, p_cell: GridCell) -> void:
	entity = p_entity
	cell = p_cell
