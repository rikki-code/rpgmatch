## Plays the queued effects of one wave generation by generation (depth along
## the `cause` chain): a generation starts when the previous one finished, and
## its effects run together. A presenter holds the next generation back only by
## awaiting inside play().
class_name WavePlayer
extends RefCounted

class Latch:
	signal done
	var remaining := 0

	func finish() -> void:
		remaining -= 1
		if remaining == 0:
			done.emit()

var _effects: Array[Effect] = []

func is_empty() -> bool:
	return _effects.is_empty()

func add(effect: Effect) -> void:
	_effects.append(effect)

func play(presenters: Dictionary, stage: BoardView3D) -> void:
	var generations: Dictionary = {}  # int -> Array[Effect]
	for effect in _effects:
		var depth := _depth(effect)
		if not generations.has(depth):
			generations[depth] = []
		generations[depth].append(effect)
	_effects.clear()

	var depths := generations.keys()
	depths.sort()
	for depth in depths:
		await _play_generation(generations[depth], presenters, stage)

func _play_generation(effects: Array, presenters: Dictionary, stage: BoardView3D) -> void:
	var latch := Latch.new()
	latch.remaining = effects.size()
	for effect: Effect in effects:
		_run(presenters[effect.get_script()], effect, stage, latch)
	# Presenters that never suspend have already finished.
	if latch.remaining > 0:
		await latch.done

func _run(presenter: EffectPresenter, effect: Effect, stage: BoardView3D, latch: Latch) -> void:
	await presenter.play(effect, stage)
	latch.finish()

static func _depth(effect: Effect) -> int:
	var depth := 0
	var cause := effect.cause
	while cause != null:
		depth += 1
		cause = cause.cause
	return depth
