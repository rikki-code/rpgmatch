## A hole: never holds a tile itself. Pins the cell directly above and the
## cell directly below itself — both are refilled straight from the pit
## when empty, instead of letting the column above collapse down into/
## through it, or the column below get pulled up through it (see
## docs/architecture.md "Модель поля" and EffectGravityColumn).
class_name PitCellKind
extends CellKind

func can_hold_tile() -> bool:
	return false

func display_name() -> String:
	return "pit"

func pinned_neighbors(cell: GridCell) -> Array[GridCell]:
	var result: Array[GridCell] = []
	for dir in [GridDirection.Dir.UP, GridDirection.Dir.DOWN]:
		var neighbor := cell.neighbor(dir)
		if neighbor != null and neighbor.kind.can_hold_tile():
			result.append(neighbor)
	return result
