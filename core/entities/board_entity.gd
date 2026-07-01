## Base for anything that can occupy a GridCell (tile, obstacle, and later
## a frozen-tile wrapper, etc).
class_name BoardEntity
extends RefCounted

func display_name() -> String:
	return "entity"

## Whether gravity may pull this entity down when the cell below empties.
## Default true (tiles fall). Obstacles/enemies override to false so gravity
## treats them as a fixed floor instead of moving them.
func can_fall() -> bool:
	return true
