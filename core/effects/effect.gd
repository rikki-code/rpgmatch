## Effects are the one uniform mechanism for cascades and chain reactions:
## execute() mutates the board and may return further effects, which the
## EffectResolver queues up and runs next. A bomb explosion, for example,
## is just an effect that returns a handful of EffectBlastDamage — no
## special-casing needed anywhere else.
class_name Effect
extends RefCounted

## The effect whose execute() returned this one (null for a root); set by EffectResolver.
var cause: Effect

func execute(_board: BoardGraph) -> Array[Effect]:
	return []
