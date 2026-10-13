## The level-growth shapes battle progression uses, so every stat curve
## (units, AI skill, combo, board size) is one call instead of hand-rolled math.
class_name LevelCurve
extends RefCounted

## Level-1 `base` grown by `growth` (a share of base) per level after the first.
static func percent(base: float, growth: float, level: int) -> float:
	return base * (1.0 + growth * (level - 1))

static func linear(start: float, per_level: float, level: int, cap: float) -> float:
	return minf(start + per_level * (level - 1), cap)

## +1 every `levels_per_step` levels after the first.
static func stepped(start: int, levels_per_step: int, level: int, cap: int) -> int:
	return mini(start + floori((level - 1) / float(levels_per_step)), cap)
