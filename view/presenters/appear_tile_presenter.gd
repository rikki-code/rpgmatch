## A tile appears: falls in from above, or pops in place and holds its generation until the pop ends.
class_name AppearTilePresenter
extends EffectPresenter

# Falling tiles sound when they land (below); an in-place pop sounds at once.
func cue_for(effect: Effect) -> StringName:
	return &"tile_pop" if (effect as EffectAppearTile).fall_distance <= 0 else &""

func play(effect: Effect, stage: BoardView3D) -> void:
	var appear := effect as EffectAppearTile
	if appear.tile == null or appear.cell.occupant != appear.tile:
		return
	var tween := stage.tiles.spawn(appear.tile, appear.cell, appear.fall_distance, appear.reveal_distance)
	if appear.fall_distance > 0 and tween != null:
		tween.finished.connect(Audio.play.bind(&"tile_land"))
	if appear.fall_distance <= 0 and tween != null:
		await stage.finished(tween)
