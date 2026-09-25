## Random quest target: a board color or one of the known bonus kinds, never
## one already active. target_count scales with difficulty; bonus kinds get
## a much narrower range than colors since they're far rarer on the board.
class_name RandomQuestGenerator
extends QuestGenerator

const BONUS_KIND_IDS: Array[StringName] = [&"bomb", &"arrow_blaster", &"prism"]
const BONUS_DISPLAY_NAMES := {
	&"bomb": "Bombs",
	&"arrow_blaster": "Arrow Blasters",
	&"prism": "Prisms",
}
const COLOR_DISPLAY_NAMES := ["Red", "Blue", "Green", "Yellow", "Purple", "Orange"]

var bonus_chance: float = 0.15

var color_min_count: int = 8
var color_max_count: int = 20
var color_growth_per_level: int = 2

var bonus_min_count: int = 1
var bonus_max_count: int = 3
var bonus_growth_per_level: int = 1

func generate_one(board: BoardGraph, difficulty: int = 0, excluded_kinds: Array[StringName] = []) -> QuestDefinition:
	var candidates := _candidate_kinds(board, excluded_kinds)
	if candidates.is_empty():
		return null
	var kind: StringName = candidates[board.rng.randi_range(0, candidates.size() - 1)]

	var quest := QuestDefinition.new()
	quest.target_kind_id = kind
	if BONUS_KIND_IDS.has(kind):
		quest.display_name = "Destroy %s" % BONUS_DISPLAY_NAMES.get(kind, String(kind))
		quest.target_count = board.rng.randi_range(
			bonus_min_count + difficulty * bonus_growth_per_level,
			bonus_max_count + difficulty * bonus_growth_per_level)
	else:
		var color := int(String(kind).substr(6))
		quest.display_name = "Destroy %s Tiles" % COLOR_DISPLAY_NAMES[color % COLOR_DISPLAY_NAMES.size()]
		quest.target_count = board.rng.randi_range(
			color_min_count + difficulty * color_growth_per_level,
			color_max_count + difficulty * color_growth_per_level)
	return quest

## Tries the bonus category first (weighted by bonus_chance); falls back to
## colors if that roll misses or every bonus kind is already active.
func _candidate_kinds(board: BoardGraph, excluded: Array[StringName]) -> Array[StringName]:
	if board.rng.randf() < bonus_chance:
		var bonus_pool: Array[StringName] = []
		for kind in BONUS_KIND_IDS:
			if not excluded.has(kind):
				bonus_pool.append(kind)
		if not bonus_pool.is_empty():
			return bonus_pool

	var color_pool: Array[StringName] = []
	for color in range(board.color_count):
		var kind := StringName("color_%d" % color)
		if not excluded.has(kind):
			color_pool.append(kind)
	return color_pool
