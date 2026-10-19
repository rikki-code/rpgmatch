## Base for a pooled one-shot board VFX; the pool takes it back when its tween ends.
class_name Vfx
extends Node3D

# Emitted by projectiles when they reach the target.
signal arrived

var pool: VfxPool
var scene: PackedScene
var light_on := false

func _run(duration: float, update: Callable) -> void:
	visible = true
	var tween := pool.tracker.track(create_tween())
	tween.tween_method(update, 0.0, 1.0, duration)
	tween.finished.connect(pool.release.bind(self))

func _reset() -> void:
	pass
