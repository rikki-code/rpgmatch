## A tile appears: falls in from above, or pops in place and holds its generation until the pop ends.
class_name AppearTilePresenter
extends EffectPresenter

func play(effect: Effect, stage: BoardView3D) -> void:
	var appear := effect as EffectAppearTile
	if appear.tile == null or appear.cell.occupant != appear.tile:
		return
	var tween := stage.tiles.spawn(appear.tile, appear.cell, appear.fall_distance, appear.reveal_distance)
	if appear.fall_distance <= 0 and tween != null:
		await stage.finished(tween)
