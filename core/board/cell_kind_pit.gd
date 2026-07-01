## A hole: never holds a tile itself. Otherwise it's just an ordinary
## segment boundary, same as the board's own edge or a gap on a non-
## rectangular board (see EffectGravityColumn) — nothing about it needs
## special-casing:
## - The segment above it falls and rests directly on top of it, exactly
##   like a segment resting on the board's bottom edge. The pit is its
##   floor, not a freeze on its own bottom-most cell.
## - The segment below it top-spawns fresh tiles the same way a segment
##   touching the board's top edge does. The pit is its ceiling/spawn
##   source, not a freeze on its own top-most cell.
class_name PitCellKind
extends CellKind

func can_hold_tile() -> bool:
	return false

func display_name() -> String:
	return "pit"
