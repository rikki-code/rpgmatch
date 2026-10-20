## Lifetime counters of one mode. Keys are shared across modes (see StatsRecorder);
## a ModeDefinition picks which ones to show.
class_name ModeStats
extends RefCounted

const RUNS := &"runs"
const TILES := &"tiles"
const BEST_SCORE := &"best_score"
const WINS := &"wins"
const LOSSES := &"losses"
const BEST_LEVEL := &"best_level"

var values: Dictionary = {}  # StringName -> int

func value_of(key: StringName) -> int:
	return values.get(key, 0)

func add(key: StringName, amount := 1) -> void:
	values[key] = value_of(key) + amount

func raise(key: StringName, value: int) -> void:
	values[key] = maxi(value_of(key), value)

func to_dict() -> Dictionary:
	return values.duplicate()

## JSON turns every number into a float.
static func from_dict(data: Dictionary) -> ModeStats:
	var stats := ModeStats.new()
	for key in data:
		stats.values[StringName(key)] = int(data[key])
	return stats
