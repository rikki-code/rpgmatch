## Data-only quest target: destroy target_count tiles matching target_kind_id.
## Resource so hand-built levels can author a fixed list, like BoardLayout.
class_name QuestDefinition
extends Resource

@export var target_kind_id: StringName
@export var target_count: int = 1
@export var display_name: String = ""
