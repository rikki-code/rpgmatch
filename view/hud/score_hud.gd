## Score + combo readout: the number rolls up smoothly instead of jumping,
## and punches bigger the higher the combo — the usual gacha/mobile counter
## feel.
class_name ScoreHud
extends Control

@onready var _score_label: Label = $ScoreLabel
@onready var _combo_label: Label = $ComboLabel

var _target_score: int = 0
var _displayed_score: int = 0
var _count_tween: Tween
var _score_punch_tween: Tween
var _combo_punch_tween: Tween
## Awards landing in the same frame (a cascade wave) sum into one popup
## instead of spawning one each — flushed deferred, once per frame.
var _pending_popup_amount: int = 0

func setup(score_tracker: ScoreTracker) -> void:
	_score_label.pivot_offset = _score_label.size / 2.0
	_combo_label.pivot_offset = _combo_label.size / 2.0
	_score_label.text = "Score: 0"
	_combo_label.text = ""
	_combo_label.modulate.a = 0.0
	score_tracker.score_awarded.connect(_on_score_awarded)
	score_tracker.combo_reset.connect(_on_combo_reset)

func _on_score_awarded(amount: int, multiplier: int, _cell: GridCell, _entity: BoardEntity) -> void:
	_target_score += amount
	_roll_score_to_target()
	_punch_score(multiplier)
	if multiplier > 1:
		_combo_label.text = "Combo x%d!" % multiplier
		_combo_label.modulate.a = 1.0
		_punch_combo()
	_queue_popup(amount)

## Restarting mid-roll (a fast combo) just redirects the tween, so a burst
## of awards reads as one accelerating count instead of a stutter.
func _roll_score_to_target() -> void:
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	var duration := clampf(float(_target_score - _displayed_score) / 300.0, 0.12, 0.5)
	_count_tween = create_tween()
	_count_tween.tween_method(_set_displayed_score, _displayed_score, _target_score, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_displayed_score(value: int) -> void:
	_displayed_score = value
	_score_label.text = "Score: %d" % _displayed_score

func _punch_score(multiplier: int) -> void:
	if _score_punch_tween != null and _score_punch_tween.is_valid():
		_score_punch_tween.kill()
	_score_label.scale = Vector2.ONE * clampf(1.15 + multiplier * 0.08, 1.15, 1.7)
	_score_punch_tween = create_tween()
	_score_punch_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _punch_combo() -> void:
	if _combo_punch_tween != null and _combo_punch_tween.is_valid():
		_combo_punch_tween.kill()
	_combo_label.scale = Vector2.ONE * 1.3
	_combo_punch_tween = create_tween()
	_combo_punch_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _queue_popup(amount: int) -> void:
	var was_pending := _pending_popup_amount != 0
	_pending_popup_amount += amount
	if not was_pending:
		_flush_popup.call_deferred()

## Floats a single "+N" past the score number and fades it out — everything
## queued since the last flush (a whole cascade wave, typically) sums into
## this one popup instead of spawning one per award. Spawned as a sibling
## under UILayer, not a child of this Control, so it isn't clipped by
## ScoreHud's own small rect.
func _flush_popup() -> void:
	var amount := _pending_popup_amount
	_pending_popup_amount = 0
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	popup.position = position + _score_label.position + Vector2(_score_label.size.x + 6.0, 0.0)
	get_parent().add_child(popup)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 28.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)

func _on_combo_reset() -> void:
	var tween := create_tween()
	tween.tween_property(_combo_label, "modulate:a", 0.0, 0.4)
