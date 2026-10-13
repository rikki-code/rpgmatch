## Total score + linear turn-scoped combo: the first match group resolved in
## a turn is x1, every further group adds `combo_step` — whether it's a
## separate cascade wave or a second color matched by the same swap.
## Self-subscribes to the resolver, no view wiring needed.
class_name ScoreTracker
extends RefCounted

signal score_awarded(amount: int, wave: int, cell: GridCell, entity: BoardEntity)
signal combo_wave_started(wave: int)
signal combo_reset

var total_score: int = 0
## Match waves this turn (1 = first group). Points scale by combo_factor().
var combo_wave: int = 0
## How much each extra wave adds to the multiplier: 1.0 = x1, x2, x3...
## Battle mode lowers it on early, few-color boards where cascades run long.
var combo_step := 1.0
## Bonus-tile blasts clear far more tiles than a match; only this share of
## their points counts toward combat power (total_score is unaffected).
const BLAST_POWER_FACTOR := 0.3

## Points since the last reset_combo, split by source — battle mode turns
## them into combat power (BattleContext.power_of): matches get the board's
## cascade scaling, blasts get BLAST_POWER_FACTOR instead.
var turn_match_points := 0.0
var turn_blast_points := 0.0

func _init(resolver: EffectResolver) -> void:
	resolver.effect_applied.connect(_on_effect_applied)

## Called at PhasePlayerInput.enter — fresh combo chain per turn.
func reset_combo() -> void:
	combo_wave = 0
	turn_match_points = 0.0
	turn_blast_points = 0.0
	combo_reset.emit()

## Called before resolving each destructive batch (match wave, manual/combine trigger).
func begin_wave() -> void:
	combo_wave += 1
	combo_wave_started.emit(combo_wave)

func combo_factor() -> float:
	return 1.0 + combo_step * (maxi(combo_wave, 1) - 1)

## One-off points not tied to a board destruction (e.g. a completed quest).
func award_bonus(amount: int) -> void:
	total_score += amount
	score_awarded.emit(amount, 1, null, null)

func _on_effect_applied(effect: Effect) -> void:
	var entity: BoardEntity = null
	var cell: GridCell = null
	var from_match := false
	if effect is EffectDestroyTile and effect.removed_entity != null:
		entity = effect.removed_entity
		cell = effect.cell
		from_match = effect.from_match
	elif effect is EffectEntityRemoved:
		entity = effect.entity
		cell = effect.cell
	if entity == null:
		return
	var amount := roundi(entity.score_value() * combo_factor())
	total_score += amount
	if from_match:
		turn_match_points += amount
	else:
		turn_blast_points += amount
	score_awarded.emit(amount, maxi(combo_wave, 1), cell, entity)
