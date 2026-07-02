## Pure view tag, same trick as EffectBombBlast — carries a MatchGroup's cells
## so BoardView3D can flash lightning between them. No board-state effect.
class_name EffectMatchLightning
extends Effect

var cells: Array[GridCell]

func _init(p_cells: Array[GridCell]) -> void:
	cells = p_cells

func execute(_board: BoardGraph) -> Array[Effect]:
	return []
