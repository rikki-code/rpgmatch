## Lightning between adjacent cells of a matched group.
class_name MatchLightningPresenter
extends EffectPresenter

func play(effect: Effect, stage: BoardView3D) -> void:
	var cells: Array[GridCell] = (effect as EffectMatchLightning).cells
	var in_group: Dictionary = {}  # Vector2i -> true
	for cell in cells:
		in_group[cell.position] = true
	for cell in cells:
		# RIGHT/DOWN only, so each pair is drawn once.
		for dir in [GridDirection.Dir.RIGHT, GridDirection.Dir.DOWN]:
			var neighbor := cell.neighbor(dir)
			if neighbor != null and in_group.has(neighbor.position):
				stage.vfx.lightning(BoardGeometry.lifted_world(cell.position), BoardGeometry.lifted_world(neighbor.position))
