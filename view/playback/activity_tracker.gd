## Tracks every running view tween so a wave can wait for one tween or for all.
class_name ActivityTracker
extends RefCounted

signal ended(tween: Tween)
signal idle

var _running: Dictionary = {}  # Tween -> true

func track(tween: Tween) -> Tween:
	_running[tween] = true
	tween.finished.connect(_end.bind(tween))
	return tween

# A killed tween never emits `finished`, so replacing one must go through here.
func cancel(tween: Tween) -> void:
	if tween != null and _running.has(tween):
		tween.kill()
		_end(tween)

func is_idle() -> bool:
	return _running.is_empty()

func wait(tween: Tween) -> void:
	while _running.has(tween):
		await ended

func wait_idle() -> void:
	while not _running.is_empty():
		await idle

func _end(tween: Tween) -> void:
	if not _running.erase(tween):
		return
	ended.emit(tween)
	if _running.is_empty():
		idle.emit()
