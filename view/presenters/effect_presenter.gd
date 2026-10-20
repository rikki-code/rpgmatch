## Base for the per-effect animation recipes registered in BoardView3D.
## play() starts with the effect's generation; await only animations that the
## effects it causes must wait for.
class_name EffectPresenter
extends RefCounted

func play(_effect: Effect, _stage: BoardView3D) -> void:
	pass

## Sound that starts together with play() (WavePlayer). A presenter whose sound is timed
## inside its animation (blasts, landings) leaves this empty and calls Audio itself.
func cue_for(_effect: Effect) -> StringName:
	return &""
