## Base for the per-effect animation recipes registered in BoardView3D.
## play() starts with the effect's generation; await only animations that the
## effects it causes must wait for.
class_name EffectPresenter
extends RefCounted

func play(_effect: Effect, _stage: BoardView3D) -> void:
	pass
