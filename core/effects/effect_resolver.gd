## Drains a queue of Effects: each executed effect can enqueue more, so
## chain reactions (cascades, explosions) fall out of this loop for free.
## Emits a signal per applied effect for the view layer to react to.
class_name EffectResolver
extends RefCounted

signal effect_applied(effect: Effect)

var board: BoardGraph

func _init(p_board: BoardGraph) -> void:
	board = p_board

func resolve(initial_effects: Array[Effect]) -> void:
	var queue: Array[Effect] = initial_effects.duplicate()
	while not queue.is_empty():
		var effect: Effect = queue.pop_front()
		var produced := effect.execute(board)
		effect_applied.emit(effect)
		if not produced.is_empty():
			queue.append_array(produced)
