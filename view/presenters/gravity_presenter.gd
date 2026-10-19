## Every tile pulled down by a gravity pass drops on its own.
class_name GravityPresenter
extends EffectPresenter

func play(effect: Effect, stage: BoardView3D) -> void:
	for move: TileMove in (effect as EffectGravityColumn).moves:
		stage.tiles.move(move.entity, move.to)
