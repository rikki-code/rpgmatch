## Base cell kind. Board gravity/generation code calls these hooks
## polymorphically instead of branching on a cell-kind enum.
class_name CellKind
extends RefCounted

func can_hold_tile() -> bool:
	return true

## Cells this kind "pins" next to itself: gravity treats a pinned cell as a
## fixed slot, refilled only by whoever pinned it — never compacted into by
## tiles further away, and it blocks tiles on its far side from sliding
## through where it sits. A normal cell pins nothing. A pit pins the cell
## directly above and below itself (see PitCellKind), which is what splits
## one physical column into independent falling segments around a pit.
func pinned_neighbors(_cell: GridCell) -> Array[GridCell]:
	return []

func display_name() -> String:
	return "cell"
