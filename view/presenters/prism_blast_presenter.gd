## Prism blast: a bolt, tinted with the blast color, flies to every target.
class_name PrismBlastPresenter
extends BlastPresenter

func _launch(blast: EffectBlast, stage: BoardView3D) -> Vfx:
	var color_index := (blast as EffectPrismBlast).color
	var color := TileView.TILE_COLORS[color_index % TileView.TILE_COLORS.size()] if color_index >= 0 else Color.WHITE
	var origin_world := BoardGeometry.lifted_world(blast.origin.position)
	var first: Vfx = null
	for cell in blast.cells:
		var bolt: Vfx = stage.vfx.prism_bolt(origin_world, BoardGeometry.lifted_world(cell.position), color)
		if first == null:
			first = bolt
	return first
