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
const WIDTH := 230.0
const COMPACT_WIDTH := 150.0
const BUTTON_WIDTH := 95.0
## Touch-friendly.
const BUTTON_HEIGHT := 44.0
const COMPACT_BUTTON_WIDTH := 60.0
const POWER_WIDTH := 104.0
const COMBO_WIDTH := 52.0
const COMPACT_POWER_WIDTH := 76.0
const COMPACT_COMBO_WIDTH := 40.0

var character: Character
var _style: StyleBoxFlat
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_label: Label
var _intent_label: Label
var _power_label: Label
var _combo_label: Label
## Power + combo on one line; both fixed-width so the line never shifts.
var _power_row: HBoxContainer
var _power_counter: RollingCounter
var _shown_combo := 1.0
var _combo_punch_tween: Tween
var _action_bar: HBoxContainer
var _action_buttons := {}  # BattleAction -> Button
var _default_action: BattleAction
var _active := false
var _targeted := false
## Target of an own-side action (shield) — drawn in the shield color.
var _targeted_own_side := false
## Charge aura scene from the battle FX pack (BattleFx.AURA_SCENE).
var _aura: Control
var _aura_tween: Tween

func setup(p_character: Character, actions: Array[BattleAction]) -> void:
	character = p_character
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.09, 0.09, 0.12, 0.92)
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", _style)
	_build_aura()

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
	_power_row = HBoxContainer.new()
	_power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_power_row.add_theme_constant_override("separation", 12)
	box.add_child(_power_row)
	_power_label = _make_label(_power_row, 20)
	_power_label.add_theme_color_override("font_color", BORDER_ACTIVE)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.custom_minimum_size.x = POWER_WIDTH
	_power_counter = RollingCounter.new(_power_label, "Power %d")
	_combo_label = _make_label(_power_row, 14)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.size_flags_vertical = Control.SIZE_FILL
	_combo_label.custom_minimum_size.x = COMBO_WIDTH
	# Keeps its slot (transparent until a combo) so the power line never shifts.
	_combo_label.text = " "
	_combo_label.modulate.a = 0.0
	_combo_label.resized.connect(func() -> void: _combo_label.pivot_offset = _combo_label.size / 2.0)

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
	_power_row.visible = active
	if active:
		set_intent(_default_action, null)
		set_power(0, 0)
	else:
		set_charge(0.0, Color.WHITE)
	_update_border()

## Charge aura; `intensity` 0..1, 0 hides it.
func set_charge(intensity: float, color: Color) -> void:
	_aura.set_energy_color(color)
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	if intensity > 0.0:
		_aura.visible = true
	_aura_tween = create_tween()
	_aura_tween.tween_method(_aura.set_intensity, _aura.get_intensity(), intensity, 0.25)
	if intensity == 0.0:
		_aura_tween.tween_callback(func() -> void: _aura.visible = false)

func _build_aura() -> void:
	_aura = BattleFx.AURA_SCENE.instantiate()
	_aura.visible = false
	add_child(_aura)

func _process(_delta: float) -> void:
	if _aura.visible:
		_aura.fit(get_global_rect())

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

## Power rolls up like the score; the combo line punches only when the combo grows.
func set_power(power: int, combo: float) -> void:
	if power <= 0:
		_power_counter.reset()
		_shown_combo = 1.0
		_combo_label.modulate.a = 0.0
		return
	_power_counter.roll_to(power, clampf(1.1 + (combo - 1.0) * 0.3, 1.1, 1.6))
	if combo > _shown_combo:
		_shown_combo = combo
		_combo_label.text = "x%.1f" % combo
		_combo_label.modulate.a = 1.0
		if _combo_punch_tween != null and _combo_punch_tween.is_valid():
			_combo_punch_tween.kill()
		_combo_label.scale = Vector2.ONE * 1.4
		_combo_punch_tween = create_tween()
		_combo_punch_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The punch deepens with the hit's share of max HP, crits on top.
func play_hit(damage: int, crit: bool) -> void:
	refresh()
	_float_text(("CRIT -%d" if crit else "-%d") % damage, Color(1, 0.6, 0.1) if crit else Color(1, 0.3, 0.3))
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(self, "modulate", Color.WHITE if character.is_alive() else DEAD_MODULATE, 0.3)
	var weight := clampf(float(damage) / character.max_hp * 2.0, 0.0, 1.0)
	scale = Vector2.ONE * (lerpf(0.95, 0.82, weight) - (0.05 if crit else 0.0))
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

## Narrower card for a row of five on a portrait screen.
func set_compact(compact: bool) -> void:
	custom_minimum_size.x = COMPACT_WIDTH if compact else WIDTH
	_style.set_content_margin_all(8.0 if compact else 12.0)
	_power_label.custom_minimum_size.x = COMPACT_POWER_WIDTH if compact else POWER_WIDTH
	_power_label.add_theme_font_size_override("font_size", 16 if compact else 20)
	_combo_label.custom_minimum_size.x = COMPACT_COMBO_WIDTH if compact else COMBO_WIDTH
	_power_row.add_theme_constant_override("separation", 6 if compact else 12)
	for button: Button in _action_buttons.values():
		button.custom_minimum_size.x = COMPACT_BUTTON_WIDTH if compact else BUTTON_WIDTH

func _make_action_button(action: BattleAction) -> void:
	var button := Button.new()
	button.text = action.display_name()
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.pressed.connect(func() -> void: action_picked.emit(action))
	_action_bar.add_child(button)
	_action_buttons[action] = button

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(character)
