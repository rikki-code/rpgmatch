## Total score + linear turn-scoped combo multiplier: the first match group
## resolved in a turn is x1, every further group is x1 stronger — whether
## it's a separate cascade wave or a second color matched by the same swap.
## Self-subscribes to the resolver, no view wiring needed.
class_name ScoreTracker
extends RefCounted

signal score_awarded(amount: int, multiplier: int, cell: GridCell, entity: BoardEntity)
signal combo_wave_started(multiplier: int)
signal combo_reset

var total_score: int = 0
var combo_multiplier: int = 0

func _init(resolver: EffectResolver) -> void:
	resolver.effect_applied.connect(_on_effect_applied)

## Called at PhasePlayerInput.enter — fresh combo chain per turn.
func reset_combo() -> void:
	combo_multiplier = 0
	combo_reset.emit()

## Called before resolving each destructive batch (match wave, manual/combine trigger).
func begin_wave() -> void:
	combo_multiplier += 1
	combo_wave_started.emit(combo_multiplier)

## One-off points not tied to a board destruction (e.g. a completed quest).
func award_bonus(amount: int) -> void:
	total_score += amount
	score_awarded.emit(amount, 1, null, null)

func _on_effect_applied(effect: Effect) -> void:
	var entity: BoardEntity = null
	var cell: GridCell = null
	if effect is EffectDestroyTile and effect.removed_entity != null:
		entity = effect.removed_entity
		cell = effect.cell
	elif effect is EffectEntityRemoved:
		entity = effect.entity
		cell = effect.cell
	if entity == null:
		return
	var multiplier := maxi(combo_multiplier, 1)
	var amount := entity.score_value() * multiplier
	total_score += amount
	score_awarded.emit(amount, multiplier, cell, entity)
