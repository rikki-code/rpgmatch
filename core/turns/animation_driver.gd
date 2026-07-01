## Contract a TurnPhase uses to pace itself against whatever is presenting
## the board (a view, a headless test, nothing at all). Default is a no-op
## that resolves instantly, so core logic never depends on a scene existing.
## The view supplies a real implementation that awaits its tweens.
class_name AnimationDriver
extends RefCounted

func await_settle() -> void:
	pass
