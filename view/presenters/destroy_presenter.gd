## A tile leaves the board; its EntityView decides how it dies.
class_name DestroyPresenter
extends EffectPresenter

func play(effect: Effect, stage: BoardView3D) -> void:
	var entity: BoardEntity = null
	if effect is EffectDestroyTile:
		entity = effect.removed_entity
	elif effect is EffectEntityRemoved:
		entity = effect.entity
	elif effect is EffectConsumeTile:
		entity = effect.tile
	if entity != null:
		stage.tiles.destroy(entity)
