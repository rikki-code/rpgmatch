## Produces QuestDefinitions to fill QuestManager's empty slots. Hand-built
## levels skip this and give QuestManager a fixed list instead.
class_name QuestGenerator
extends RefCounted

func generate_one(_board: BoardGraph, _difficulty: int = 0, _excluded_kinds: Array[StringName] = []) -> QuestDefinition:
	return null
