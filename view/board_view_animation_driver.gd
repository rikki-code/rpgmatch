## AnimationDriver backed by a real BoardView3D: a world-cycle wave (see
## PhasePhysicsResolve) doesn't advance to the next wave until every tween
## the view started for the current wave has finished.
class_name BoardViewAnimationDriver
extends AnimationDriver

var view: BoardView3D

func _init(p_view: BoardView3D) -> void:
	view = p_view

func await_settle() -> void:
	await view.await_settled()
