## Runtime progress against a QuestDefinition.
class_name QuestProgress
extends RefCounted

var definition: QuestDefinition
var current_count: int = 0

func _init(p_definition: QuestDefinition) -> void:
	definition = p_definition

func is_complete() -> bool:
	return current_count >= definition.target_count

## Clamped so one big blast can't overshoot past the target.
func register_progress(amount: int) -> void:
	current_count = mini(current_count + amount, definition.target_count)
