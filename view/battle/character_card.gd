## One character's card: name, HP bar, shield, live turn power while it's
## their turn, a button per BattleAction (human, own turn only), floating
## damage/shield numbers. Clicking the card emits `clicked` (target pick).
class_name CharacterCard
extends PanelContainer

signal clicked(character: Character)
signal action_picked(action: BattleAction)

const BORDER_IDLE := Color(0.3, 0.3, 0.36)
const BORDER_ACTIVE := Color(1.0, 0.85, 0.2)
const BORDER_TARGET := Color(1.0, 0.35, 0.3)
const ALLY_HP_COLOR := Color(0.35, 0.8, 0.4)
const ENEMY_HP_COLOR := Color(0.85, 0.3, 0.3)
const SHIELD_COLOR := Color(0.45, 0.7, 1.0)
const DEAD_MODULATE := Color(1, 1, 1, 0.35)

var character: Character
var _style: StyleBoxFlat
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_label: Label
var _intent_label: Label
var _power_label: Label
var _action_bar: HBoxContainer
var _action_buttons := {}  # BattleAction -> Button
var _default_action: BattleAction
var _active := false
var _targeted := false
## Target of an own-side action (shield) — drawn in the shield color.
var _targeted_own_side := false

func setup(p_character: Character, actions: Array[BattleAction]) -> void:
	character = p_character
	custom_minimum_size = Vector2(230, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.09, 0.09, 0.12, 0.92)
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_make_label(box, 22).text = character.display_name
	_hp_bar = ProgressBar.new()
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.max_value = character.max_hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = ALLY_HP_COLOR if character.side == Character.Side.ALLY else ENEMY_HP_COLOR
	fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_hp_bar)

	_hp_label = _make_label(box, 16)
	_shield_label = _make_label(box, 16)
	_shield_label.add_theme_color_override("font_color", SHIELD_COLOR)
	_intent_label = _make_label(box, 16)
	_power_label = _make_label(box, 20)
	_power_label.add_theme_color_override("font_color", BORDER_ACTIVE)

	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 8)
	box.add_child(_action_bar)
	_default_action = actions[0]
	for action in actions:
		_make_action_button(action)

	gui_input.connect(_on_gui_input)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	set_active(false, false)
	refresh()

func refresh() -> void:
	_hp_bar.value = character.hp
	_hp_label.text = "HP %d / %d" % [character.hp, character.max_hp]
	_shield_label.text = "Shield %d" % character.shield
	_shield_label.visible = character.shield > 0
	modulate = Color.WHITE if character.is_alive() else DEAD_MODULATE
	_update_border()

## `human` only matters for the active card: it gets the action menu.
func set_active(active: bool, human: bool) -> void:
	_active = active
	_action_bar.visible = active and human
	_intent_label.visible = active
	_power_label.visible = active
	if active:
		set_intent(_default_action, null)
		set_power(0, 0)
	_update_border()

func set_actions_enabled(enabled: bool) -> void:
	for button: Button in _action_buttons.values():
		button.disabled = not enabled

func set_targeted(targeted: bool, own_side := false) -> void:
	_targeted = targeted
	_targeted_own_side = own_side
	_update_border()

func set_intent(action: BattleAction, target: Character) -> void:
	_intent_label.text = action.display_name() + (" → %s" % target.display_name if target != null else "")
	for other: BattleAction in _action_buttons:
		_action_buttons[other].modulate = BORDER_ACTIVE if other == action else Color.WHITE

func set_power(power: int, combo: float) -> void:
	_power_label.text = "Power %d" % power + ("   x%.1f combo" % combo if combo > 1.0 else "")
	if power > 0:
		_power_label.pivot_offset = _power_label.size / 2.0
		_power_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_power_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_hit(damage: int, crit: bool) -> void:
	refresh()
	_float_text(("CRIT -%d" if crit else "-%d") % damage, Color(1, 0.6, 0.1) if crit else Color(1, 0.3, 0.3))
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(self, "modulate", Color.WHITE if character.is_alive() else DEAD_MODULATE, 0.3)
	scale = Vector2.ONE * (0.85 if crit else 0.92)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_shield(amount: int) -> void:
	refresh()
	_float_text("+%d shield" % amount, SHIELD_COLOR)

func _update_border() -> void:
	if _active:
		_style.border_color = BORDER_ACTIVE
	elif _targeted:
		_style.border_color = SHIELD_COLOR if _targeted_own_side else BORDER_TARGET
	else:
		_style.border_color = BORDER_IDLE

## top_level so the parent containers don't lay it out — it floats freely.
func _float_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.top_level = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.position = global_position + Vector2(size.x * 0.5 - 50.0, 8.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)

func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _make_action_button(action: BattleAction) -> void:
	var button := Button.new()
	button.text = action.display_name()
	button.custom_minimum_size = Vector2(95, 36)
	button.pressed.connect(func() -> void: action_picked.emit(action))
	_action_bar.add_child(button)
	_action_buttons[action] = button

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(character)
