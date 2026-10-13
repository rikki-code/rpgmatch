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

## A tween owned by the view, not a SceneTree timer: a reload/reset frees the
## view and the tween with it, so a pending AI turn never resumes on a dead scene.
func await_delay(seconds: float) -> void:
	await view.create_tween().tween_interval(seconds).finished
