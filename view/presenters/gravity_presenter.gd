## Every tile pulled down by a gravity pass drops on its own.
class_name GravityPresenter
extends EffectPresenter

func play(effect: Effect, stage: BoardView3D) -> void:
	for move: TileMove in (effect as EffectGravityColumn).moves:
		var tween := stage.tiles.move(move.entity, move.to)
		if tween != null:
			tween.finished.connect(Audio.play.bind(&"tile_land"))
