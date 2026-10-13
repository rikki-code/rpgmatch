## Animated number on a Label: rolls toward each new target instead of
## jumping, and punches its scale (bigger for bigger combos). Re-targeting
## mid-roll redirects the running tween, so a burst reads as one accelerating
## count. Shared by ScoreHud and CharacterCard; the label should be
## center-aligned so the punch scales around the text.
class_name RollingCounter
extends RefCounted

const ROLL_SPEED := 300.0
const PUNCH_SECONDS := 0.25
## Awards arrive per destroyed tile; re-punching on each one reads as flicker.
const MIN_PUNCH_INTERVAL_MS := 120

var label: Label
var format: String
var _shown := 0
var _target := 0
var _roll_tween: Tween
var _punch_tween: Tween
var _pending_punch := 0.0
var _flush_queued := false
var _last_punch_ms := -MIN_PUNCH_INTERVAL_MS

func _init(p_label: Label, p_format: String) -> void:
	label = p_label
	format = p_format
	# Fixed-size labels (scene-sized) never emit `resized`, so set the pivot now too.
	label.pivot_offset = label.size / 2.0
	label.resized.connect(func() -> void: label.pivot_offset = label.size / 2.0)
	_show(0)

## Calls within one frame coalesce into a single roll + punch (flushed deferred).
func roll_to(value: int, punch_scale: float) -> void:
	if value == _target:
		return
	_target = value
	_pending_punch = maxf(_pending_punch, punch_scale)
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	if _roll_tween != null and _roll_tween.is_valid():
		_roll_tween.kill()
	var seconds := clampf(absf(_target - _shown) / ROLL_SPEED, 0.12, 0.5)
	_roll_tween = label.create_tween()
	_roll_tween.tween_method(_show, _shown, _target, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var now := Time.get_ticks_msec()
	if now - _last_punch_ms >= MIN_PUNCH_INTERVAL_MS:
		_last_punch_ms = now
		punch(_pending_punch)
	_pending_punch = 0.0

func punch(punch_scale: float) -> void:
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	label.scale = Vector2.ONE * punch_scale
	_punch_tween = label.create_tween()
	_punch_tween.tween_property(label, "scale", Vector2.ONE, PUNCH_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func reset(value := 0) -> void:
	for tween in [_roll_tween, _punch_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	label.scale = Vector2.ONE
	_pending_punch = 0.0
	_target = value
	_show(value)

func _show(value: int) -> void:
	_shown = value
	label.text = format % value
