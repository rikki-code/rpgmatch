## Base turn phase. A phase that finishes synchronously (physics resolve,
## an empty stub) should leave is_instant() true. A phase that waits for an
## external event (player input) overrides is_instant() to false and calls
## TurnManager.notify_phase_done() itself when it's actually done.
class_name TurnPhase
extends RefCounted

func is_instant() -> bool:
	return true

func enter(_ctx: TurnContext) -> void:
	pass

func execute(_ctx: TurnContext) -> void:
	pass

func exit(_ctx: TurnContext) -> void:
	pass
