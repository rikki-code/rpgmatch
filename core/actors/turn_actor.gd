## Base for enemies and environment agents that act during their own turn
## phase. take_turn returns effects the same way tile behaviors do, so
## enemy actions flow through the same EffectResolver/cascade machinery.
class_name TurnActor
extends RefCounted

func take_turn(_board: BoardGraph) -> Array[Effect]:
	return []
