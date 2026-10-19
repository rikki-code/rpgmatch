## Drains a queue of Effects: each executed effect can enqueue more, so
## chain reactions (cascades, explosions) fall out of this loop for free.
## Emits a signal per applied effect for the view layer to react to.
class_name EffectResolver
extends RefCounted

signal effect_applied(effect: Effect)

var board: BoardGraph

func _init(p_board: BoardGraph) -> void:
	board = p_board

## `cause` marks the roots of a batch resolved from inside an effect's execute().
func resolve(initial_effects: Array[Effect], cause: Effect = null) -> void:
	var queue: Array[Effect] = initial_effects.duplicate()
	for effect in queue:
		effect.cause = cause
	while not queue.is_empty():
		var effect: Effect = queue.pop_front()
		var produced := effect.execute(board)
		effect_applied.emit(effect)
		if not produced.is_empty():
			for next in produced:
				next.cause = effect
			queue.append_array(produced)
