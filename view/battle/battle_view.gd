## Battle screen around the shared board: ally cards left, enemy cards
## right, whose-turn banner on top, victory/defeat overlay. A pure view of
## ctx.battle — the player's picks go back through BattleContext, and only
## while the human can actually act (ctx.awaiting_player_input).
class_name BattleView
extends Control

signal restart_requested
signal exit_requested

const COLUMN_WIDTH := 250.0
const EDGE_MARGIN := 24.0

var _ctx: TurnContext
var _battle: BattleContext
var _cards: Dictionary = {}  # Character -> CharacterCard
var _allies_column: VBoxContainer
var _enemies_column: VBoxContainer
var _turn_label: Label
var _overlay: ColorRect
var _result_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_allies_column = _make_column(true)
	_enemies_column = _make_column(false)
	_build_turn_label()
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

	_battle.turn_started.connect(_on_turn_started)
	_battle.action_selected.connect(_on_action_selected)
	_battle.target_selected.connect(_on_target_selected)
	_battle.shield_gained.connect(_on_shield_gained)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.resolver.action_resolved.connect(_on_action_resolved)
	if not ctx.score_tracker.score_awarded.is_connected(_on_score_awarded):
		ctx.score_tracker.score_awarded.connect(_on_score_awarded)

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
		if _battle.human_target == null or not _battle.human_target.is_alive():
			var first := _battle.first_living(_battle.opponents_of(character))
			if first != null:
				_battle.select_target(first)
		_turn_label.text = "Your turn: pick an action, click a target, swap tiles"
	else:
		_turn_label.text = "%s's turn..." % character.display_name

func _on_action_selected(character: Character, type: BattleContext.ActionType) -> void:
	_cards[character].set_intent(type)
	if not character.controller.is_human():
		var verb := "attack" if type == BattleContext.ActionType.ATTACK else "defend"
		_turn_label.text = "%s prepares to %s" % [character.display_name, verb]

func _on_target_selected(target: Character) -> void:
	for character: Character in _cards:
		if character.side == Character.Side.ENEMY:
			_cards[character].set_targeted(character == target)

func _on_score_awarded(_amount: int, _multiplier: int, _cell: GridCell, _entity: BoardEntity) -> void:
	if not visible or _battle == null or _battle.active_character == null:
		return
	var actor := _battle.active_character
	_cards[actor].set_power(actor.power_from_points(_ctx.score_tracker.turn_points), _ctx.score_tracker.combo_multiplier)

func _on_action_resolved(action: CombatAction, damage: int, is_crit: bool) -> void:
	var target_card: CharacterCard = _cards[action.target]
	target_card.play_hit(damage, is_crit)
	if not action.target.is_alive():
		target_card.set_targeted(false)
	_turn_label.text = "%s hits %s for %d%s" % [action.actor.display_name, action.target.display_name, damage, "  CRIT!" if is_crit else ""]

func _on_shield_gained(character: Character, amount: int) -> void:
	_cards[character].play_shield(amount)
	_turn_label.text = "%s raises a shield (+%d)" % [character.display_name, amount]

func _on_battle_ended(victory: bool) -> void:
	for character: Character in _cards:
		_cards[character].set_active(false, false)
	_result_label.text = "Victory!" if victory else "Defeat"
	_overlay.visible = true

func _on_card_clicked(character: Character) -> void:
	if character.side == Character.Side.ENEMY and _ctx.awaiting_player_input:
		_battle.select_target(character)

func _on_action_picked(type: BattleContext.ActionType) -> void:
	if _ctx.awaiting_player_input and _battle.active_character.controller.is_human():
		_battle.select_action(type)

func _add_card(character: Character, column: VBoxContainer) -> void:
	var card := CharacterCard.new()
	column.add_child(card)
	card.setup(character)
	card.clicked.connect(_on_card_clicked)
	card.action_picked.connect(_on_action_picked)
	_cards[character] = card

func _make_column(left: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
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

	var restart := Button.new()
	restart.text = "Restart battle"
	restart.custom_minimum_size = Vector2(220, 44)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(restart)
	var leave := Button.new()
	leave.text = "Back to infinite mode"
	leave.custom_minimum_size = Vector2(220, 44)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(leave)
