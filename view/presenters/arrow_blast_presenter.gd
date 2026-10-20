## Arrow blast: two bolts fly from the origin to the ends of the line.
class_name ArrowBlastPresenter
extends BlastPresenter

func _charge_cue() -> StringName:
	return &"arrow_charge"

func _launch_cue() -> StringName:
	return &"arrow_launch"

func _blast_cue() -> StringName:
	return &"arrow_blast"

func _launch(blast: EffectBlast, stage: BoardView3D) -> Vfx:
	if blast.cells.is_empty():
		return null
	var varies_x := (blast as EffectArrowBlast).axis == ArrowBlasterCore.Axis.ROW
	var min_pos := blast.origin.position
	var max_pos := blast.origin.position
	for cell in blast.cells:
		var coord := cell.position.x if varies_x else cell.position.y
		var min_coord := min_pos.x if varies_x else min_pos.y
		var max_coord := max_pos.x if varies_x else max_pos.y
		if coord < min_coord:
			min_pos = cell.position
		if coord > max_coord:
			max_pos = cell.position
	var origin_world := BoardGeometry.lifted_world(blast.origin.position)
	var first := stage.vfx.arrow_bolt(origin_world, BoardGeometry.lifted_world(min_pos))
	var second := stage.vfx.arrow_bolt(origin_world, BoardGeometry.lifted_world(max_pos))
	return first if first != null else second
