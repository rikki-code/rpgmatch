## Battle screen around the shared board: ally cards left, enemy cards
## right, whose-turn banner on top, victory/defeat overlay. A pure view of
## ctx.battle — the player's picks go back through BattleContext, and only
## while the human can actually act (ctx.awaiting_player_input).
class_name BattleView
extends Control

## Victory -> next level on a new board; defeat -> retry the same level.
signal continue_requested(victory: bool)
signal exit_requested

const COLUMN_WIDTH := 250.0
const EDGE_MARGIN := 24.0

var _ctx: TurnContext
var _battle: BattleContext
var _cards: Dictionary = {}  # Character -> CharacterCard
var _allies_column: VBoxContainer
var _enemies_column: VBoxContainer
var _turn_label: Label
var _level_label: Label
var _continue_button: Button
var _overlay: ColorRect
var _result_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_allies_column = _make_column(true)
	_enemies_column = _make_column(false)
	_build_turn_label()
	_build_level_label()
	_build_overlay()

func setup(ctx: TurnContext) -> void:
	_ctx = ctx
	_battle = ctx.battle
	for card: CharacterCard in _cards.values():
		card.queue_free()
	_cards.clear()
	for character in _battle.allies:
		_add_card(character, _allies_column)
	for character in _battle.enemies:
		_add_card(character, _enemies_column)
	_overlay.visible = false
	_turn_label.text = ""
	_level_label.text = "Level %d" % _battle.level

	_battle.turn_started.connect(_on_turn_started)
	_battle.action_selected.connect(_on_action_selected)
	_battle.target_selected.connect(_on_target_selected)
	_battle.shield_gained.connect(_on_shield_gained)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.resolver.action_resolved.connect(_on_action_resolved)
	if not ctx.score_tracker.score_awarded.is_connected(_on_score_awarded):
		ctx.score_tracker.score_awarded.connect(_on_score_awarded)

## Screen areas the board must stay clear of (see GameRoot._hud_insets).
func hud_rects() -> Array[Rect2]:
	return [_allies_column.get_global_rect(), _enemies_column.get_global_rect(), _turn_label.get_global_rect(), _level_label.get_global_rect()]

func _process(_delta: float) -> void:
	if _battle == null or _battle.active_character == null:
		return
	var card: CharacterCard = _cards.get(_battle.active_character)
	if card != null:
		card.set_actions_enabled(_ctx.awaiting_player_input)

func _on_turn_started(character: Character) -> void:
	for other: Character in _cards:
		_cards[other].set_active(other == character, other.controller.is_human())
	if character.controller.is_human():
		_turn_label.text = "Your turn: pick an action, click any card as the target, then swap tiles"
	else:
		_turn_label.text = "%s's turn..." % character.display_name
	_update_target_marks()

func _on_action_selected(character: Character, action: BattleAction) -> void:
	_update_target_marks()
	if not character.controller.is_human() and _battle.pending_target != null:
		_turn_label.text = "%s prepares to %s %s" % [character.display_name, action.display_name().to_lower(), _battle.pending_target.display_name]

func _on_target_selected(_target: Character) -> void:
	_update_target_marks()

func _on_score_awarded(_amount: int, _wave: int, _cell: GridCell, _entity: BoardEntity) -> void:
	if not visible or _battle == null or _battle.active_character == null:
		return
	var actor := _battle.active_character
	_cards[actor].set_power(_battle.power_of(actor, _ctx.score_tracker), _ctx.score_tracker.combo_factor())

func _on_action_resolved(action: CombatAction, damage: int, is_crit: bool) -> void:
	var target_card: CharacterCard = _cards[action.target]
	target_card.play_hit(damage, is_crit)
	if not action.target.is_alive():
		_update_target_marks()
	_turn_label.text = "%s hits %s for %d%s" % [action.actor.display_name, action.target.display_name, damage, "  CRIT!" if is_crit else ""]

func _on_shield_gained(character: Character, amount: int) -> void:
	_cards[character].play_shield(amount)
	var actor := _battle.active_character
	if character == actor:
		_turn_label.text = "%s raises a shield (+%d)" % [actor.display_name, amount]
	else:
		_turn_label.text = "%s shields %s (+%d)" % [actor.display_name, character.display_name, amount]

## Target border (red = attack-like, blue = own-side action) + the active card's "Action -> target" line.
func _update_target_marks() -> void:
	var action := _battle.pending_action
	var own_side := action != null and action.targets_own_side()
	for character: Character in _cards:
		_cards[character].set_targeted(not _battle.ended and character == _battle.pending_target, own_side)
	var actor := _battle.active_character
	if actor != null and action != null:
		_cards[actor].set_intent(action, _battle.pending_target)

func _on_battle_ended(victory: bool) -> void:
	for character: Character in _cards:
		_cards[character].set_active(false, false)
	_update_target_marks()
	_result_label.text = "Victory!" if victory else "Defeat"
	_continue_button.text = "Next battle" if victory else "Retry"
	_overlay.visible = true

func _on_card_clicked(character: Character) -> void:
	if _ctx.awaiting_player_input and _is_human_turn():
		_battle.select_target(character)

func _on_action_picked(action: BattleAction) -> void:
	if _ctx.awaiting_player_input and _is_human_turn():
		_battle.select_action(action)

func _is_human_turn() -> bool:
	var actor := _battle.active_character
	return actor != null and actor.controller.is_human() and not _battle.ended

func _add_card(character: Character, column: VBoxContainer) -> void:
	var card := CharacterCard.new()
	column.add_child(card)
	card.setup(character, _battle.actions)
	card.clicked.connect(_on_card_clicked)
	card.action_picked.connect(_on_action_picked)
	_cards[character] = card

func _make_column(left: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.anchor_left = 0.0 if left else 1.0
	column.anchor_right = column.anchor_left
	column.offset_top = 80.0
	column.offset_bottom = -120.0
	column.offset_left = EDGE_MARGIN if left else -EDGE_MARGIN - COLUMN_WIDTH
	column.offset_right = EDGE_MARGIN + COLUMN_WIDTH if left else -EDGE_MARGIN
	return column

func _build_turn_label() -> void:
	_turn_label = Label.new()
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 26)
	_turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_turn_label.add_theme_constant_override("outline_size", 6)
	add_child(_turn_label)
	_turn_label.anchor_left = 0.5
	_turn_label.anchor_right = 0.5
	_turn_label.offset_left = -400.0
	_turn_label.offset_right = 400.0
	_turn_label.offset_top = 16.0
	_turn_label.offset_bottom = 56.0

func _build_level_label() -> void:
	_level_label = Label.new()
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label.add_theme_font_size_override("font_size", 30)
	_level_label.add_theme_color_override("font_color", CharacterCard.BORDER_ACTIVE)
	_level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_level_label.add_theme_constant_override("outline_size", 6)
	add_child(_level_label)
	_level_label.position = Vector2(EDGE_MARGIN, 16.0)

## Blocks the board while shown (MOUSE_FILTER_STOP) — the battle is over.
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.visible = false
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 64)
	_result_label.add_theme_color_override("font_color", CharacterCard.BORDER_ACTIVE)
	box.add_child(_result_label)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(220, 44)
	_continue_button.pressed.connect(func() -> void: continue_requested.emit(_battle.is_victory()))
	box.add_child(_continue_button)
	var leave := Button.new()
	leave.text = "Back to infinite mode"
	leave.custom_minimum_size = Vector2(220, 44)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(leave)
