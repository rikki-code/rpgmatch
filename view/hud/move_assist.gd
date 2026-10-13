## Helps a stuck player on their turn: after HINT_DELAY_SECONDS it asks for a
## move to be highlighted — picked like an AI of the battle's level would
## (MoveFinder.pick_move + AiController.skill_for_level), so hints get better
## with the level; outside battle it's the best move. With no legal move at
## all it shows a Shuffle button instead (ShuffleController).
class_name MoveAssist
extends Control

signal hint_requested(move: MoveFinder.Move)

const HINT_DELAY_SECONDS := 10.0

var _ctx: TurnContext
var _editor: EditorModeController
var _waiting := false
var _idle_seconds := 0.0
var _hinted := false
var _shuffle_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_shuffle_button = Button.new()
	_shuffle_button.text = "No moves — Shuffle"
	_shuffle_button.add_theme_font_size_override("font_size", 28)
	_shuffle_button.custom_minimum_size = Vector2(320, 64)
	_shuffle_button.visible = false
	_shuffle_button.pressed.connect(func() -> void: _ctx.shuffle_controller.try_shuffle())
	center.add_child(_shuffle_button)

func setup(ctx: TurnContext, editor: EditorModeController) -> void:
	_ctx = ctx
	_editor = editor
	ctx.shuffle_controller.shuffled.connect(_restart_wait)

func _process(delta: float) -> void:
	if _ctx == null:
		return
	var waiting := _ctx.awaiting_player_input and not _editor.active
	if waiting != _waiting:
		_waiting = waiting
		_restart_wait()
	if not _waiting or _hinted or _shuffle_button.visible:
		return
	_idle_seconds += delta
	if _idle_seconds >= HINT_DELAY_SECONDS:
		_hinted = true
		var skill := AiController.skill_for_level(_ctx.battle.level) if _ctx.battle != null else AiController.MAX_SKILL
		var match_weight := _ctx.battle.power_multiplier if _ctx.battle != null else 1.0
		var move := MoveFinder.pick_move(_ctx.board, skill, _ctx.board.rng, match_weight)
		if move != null:
			hint_requested.emit(move)

func _restart_wait() -> void:
	_idle_seconds = 0.0
	_hinted = false
	_shuffle_button.visible = _waiting and not MoveFinder.has_move(_ctx.board)
