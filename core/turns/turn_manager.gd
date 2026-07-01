## Drives a configurable ordered list of TurnPhase objects
## (player input -> environment -> enemies -> physics resolve, by default).
## Reordering or adding phases is just editing the array passed in — no
## branching in this class.
class_name TurnManager
extends RefCounted

signal phase_entered(phase: TurnPhase)
signal turn_cycle_completed

var phases: Array[TurnPhase] = []
var ctx: TurnContext
var _index: int = -1

func _init(p_ctx: TurnContext, p_phases: Array[TurnPhase]) -> void:
	ctx = p_ctx
	phases = p_phases

func start() -> void:
	_index = -1
	_advance()

func notify_phase_done() -> void:
	_advance()

func _advance() -> void:
	if _index >= 0:
		phases[_index].exit(ctx)
	_index += 1
	if _index >= phases.size():
		_index = -1
		turn_cycle_completed.emit()
		await _advance()
		return

	var phase := phases[_index]
	phase_entered.emit(phase)
	phase.enter(ctx)
	await phase.execute(ctx)
	if phase.is_instant():
		notify_phase_done()
