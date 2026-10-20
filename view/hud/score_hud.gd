## Score + combo readout: the number rolls up smoothly instead of jumping,
## and punches bigger the higher the combo — the usual gacha/mobile counter
## feel. Always centered above the board (dock_to_board).
class_name ScoreHud
extends Control

const TOP := 40.0
const DOCK_GAP := 8.0

@onready var _score_label: Label = $ScoreLabel
@onready var _combo_label: Label = $ComboLabel

var _score_tracker: ScoreTracker
var _score_counter: RollingCounter
var _combo_punch_tween: Tween
## Awards landing in the same frame (a cascade wave) sum into one popup
## instead of spawning one each — flushed deferred, once per frame.
var _pending_popup_amount: int = 0

func setup(score_tracker: ScoreTracker) -> void:
	_score_tracker = score_tracker
	_score_counter = RollingCounter.new(_score_label, "Score: %d")
	_score_counter.reset(score_tracker.total_score)
	_combo_label.pivot_offset = _combo_label.size / 2.0
	_combo_label.text = ""
	_combo_label.modulate.a = 0.0
	score_tracker.score_awarded.connect(_on_score_awarded)
	score_tracker.combo_reset.connect(_on_combo_reset)

## Reserved band at the top of the screen (GameRoot._free_screen_rect).
func hud_rects() -> Array[Rect2]:
	var screen := get_viewport_rect().size
	return [Rect2(Vector2((screen.x - size.x) / 2.0, TOP), size)]

## Text over falling tiles is unreadable, so the score stays above the spawn lane.
func dock_to_board(board_rect: Rect2, spawn_lane: float) -> void:
	position = Vector2(board_rect.get_center().x - size.x / 2.0, maxf(TOP, board_rect.position.y - spawn_lane - size.y - DOCK_GAP))

func _on_score_awarded(amount: int, multiplier: int, _cell: GridCell, _entity: BoardEntity) -> void:
	_score_counter.roll_to(_score_tracker.total_score, clampf(1.15 + multiplier * 0.08, 1.15, 1.7))
	if multiplier > 1:
		_combo_label.text = "Combo x%d!" % multiplier
		_combo_label.modulate.a = 1.0
		_punch_combo()
	_queue_popup(amount)

func _punch_combo() -> void:
	if _combo_punch_tween != null and _combo_punch_tween.is_valid():
		_combo_punch_tween.kill()
	_combo_label.scale = Vector2.ONE * 1.3
	_combo_punch_tween = create_tween()
	_combo_punch_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _queue_popup(amount: int) -> void:
	# Hidden in battle mode; popups would float at this node's idle corner position.
	if not is_visible_in_tree():
		return
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
	var text_end := (_score_label.size.x + _score_label.get_minimum_size().x) / 2.0
	popup.position = position + _score_label.position + Vector2(text_end + 6.0, 0.0)
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
