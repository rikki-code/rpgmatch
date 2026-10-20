## Base cell kind. Board gravity/generation code calls these hooks
## polymorphically instead of branching on a cell-kind enum.
class_name CellKind
extends RefCounted

func can_hold_tile() -> bool:
	return true

func display_name() -> String:
	return "cell"

## Saved with the board; a new kind also joins CellKindCodec.
func id() -> StringName:
	return &""

func visual_kind() -> StringName:
	return &"ground"
