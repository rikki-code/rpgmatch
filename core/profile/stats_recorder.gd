## Feeds a mode's lifetime stats from what happens in a game. Self-subscribes to
## the score tracker like QuestManager does; the owner saves when `dirty`.
class_name StatsRecorder
extends RefCounted

var dirty := false

var _stats: ModeStats
var _score: ScoreTracker

func _init(score_tracker: ScoreTracker, stats: ModeStats) -> void:
	_score = score_tracker
	_stats = stats
	score_tracker.score_awarded.connect(_on_score_awarded)

func note_level(level: int) -> void:
	_stats.raise(ModeStats.BEST_LEVEL, level)
	dirty = true

## `victory` = the allied side won.
func note_battle_ended(victory: bool) -> void:
	_stats.add(ModeStats.WINS if victory else ModeStats.LOSSES)
	dirty = true

func _on_score_awarded(_amount: int, _wave: int, _cell: GridCell, entity: BoardEntity) -> void:
	if entity != null:
		_stats.add(ModeStats.TILES)
	_stats.raise(ModeStats.BEST_SCORE, _score.total_score)
	dirty = true
