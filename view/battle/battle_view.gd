## Battle screen around the shared board: ally/enemy cards as side columns
## (landscape) or rows — enemies top, allies bottom (portrait/phones) —
## whose-turn banner on top, victory/defeat overlay. A pure view of
## ctx.battle — the player's picks go back through BattleContext, and only
## while the human can actually act (ctx.awaiting_player_input).
class_name BattleView
extends Control

## advance: victory against the AI -> next level on a new board; otherwise replay the same level.
signal continue_requested(advance: bool)
signal exit_requested

## Charge aura: visible from the first point, full once the action would
## move half the target's max HP — relative, so it reads the same at any level.
const MIN_CHARGE := 0.35
const FULL_CHARGE_HP_SHARE := 0.5
const COLUMN_WIDTH := 250.0
const EDGE_MARGIN := 24.0
## Fits the tallest (active, human) card.
const ROW_HEIGHT := 240.0
const PORTRAIT_BANNER_BOTTOM := 140.0
const DOCK_GAP := 12.0
const ROW_SEPARATION := 6.0
## Keeps the portrait banner clear of GameMenu's top-right button.
const MENU_BUTTON_CLEARANCE := GameMenu.OPEN_BUTTON_SIZE + 24.0
const COLUMN_TOP := 80.0
const COLUMN_BOTTOM_MARGIN := 120.0

var _ctx: TurnContext
var _battle: BattleContext
var _cards: Dictionary = {}  # Character -> CharacterCard
var _allies_box: BoxContainer
var _enemies_box: BoxContainer
var _portrait := false
var _turn_label: Label
var _level_label: Label
var _continue_button: Button
var _overlay: ColorRect
var _fx: BattleFx
var _result_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_allies_box = _make_box()
	_enemies_box = _make_box()
	_build_turn_label()
	_build_level_label()
	_fx = BattleFx.new()
	add_child(_fx)
	_build_overlay()
	resized.connect(_apply_layout)
	_apply_layout()

func setup(ctx: TurnContext) -> void:
	_ctx = ctx
	_battle = ctx.battle
	for card: CharacterCard in _cards.values():
		card.queue_free()
	_cards.clear()
	for character in _battle.allies:
		_add_card(character, _allies_box)
	for character in _battle.enemies:
		_add_card(character, _enemies_box)
	_overlay.visible = false
	_apply_layout()
	_turn_label.text = ""
	_level_label.text = "Level %d" % _battle.level

	_battle.turn_started.connect(_on_turn_started)
	_battle.action_selected.connect(_on_action_selected)
	_battle.target_selected.connect(_on_target_selected)
	_battle.shield_gained.connect(_on_shield_gained)
	_battle.action_launched.connect(_on_action_launched)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.character_left.connect(_on_character_left)
	_battle.resolver.action_resolved.connect(_on_action_resolved)
	if not ctx.score_tracker.score_awarded.is_connected(_on_score_awarded):
		ctx.score_tracker.score_awarded.connect(_on_score_awarded)

## Screen areas the board must stay clear of (GameRoot._free_screen_rect).
## Card boxes report their reserved bands at the screen edges, not their
## docked positions, so docking never feeds back into the camera fit.
func hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [_turn_label.get_global_rect(), _level_label.get_global_rect()]
	if _portrait:
		rects.append(Rect2(0.0, PORTRAIT_BANNER_BOTTOM, size.x, ROW_HEIGHT))
		rects.append(Rect2(0.0, size.y - EDGE_MARGIN - ROW_HEIGHT, size.x, ROW_HEIGHT))
	else:
		var height := size.y - COLUMN_TOP - COLUMN_BOTTOM_MARGIN
		rects.append(Rect2(EDGE_MARGIN, COLUMN_TOP, COLUMN_WIDTH, height))
		rects.append(Rect2(size.x - EDGE_MARGIN - COLUMN_WIDTH, COLUMN_TOP, COLUMN_WIDTH, height))
	return rects

## Pulls the card boxes against the board's edges (allies before it, enemies
## after it) instead of the screen edges, never past their reserved bands.
## Opaque cards may cover the spawn lane, so they ignore it and hug the board itself.
func dock_to_board(board_rect: Rect2, _spawn_lane: float) -> void:
	if _portrait:
		var top := clampf(board_rect.position.y - ROW_HEIGHT - DOCK_GAP, PORTRAIT_BANNER_BOTTOM, size.y)
		_enemies_box.offset_top = top
		_enemies_box.offset_bottom = top + ROW_HEIGHT
		var bottom_top := clampf(board_rect.end.y + DOCK_GAP, 0.0, size.y - EDGE_MARGIN - ROW_HEIGHT) - size.y
		_allies_box.offset_top = bottom_top
		_allies_box.offset_bottom = bottom_top + ROW_HEIGHT
	else:
		var left := clampf(board_rect.position.x - COLUMN_WIDTH - DOCK_GAP, EDGE_MARGIN, size.x)
		_allies_box.offset_left = left
		_allies_box.offset_right = left + COLUMN_WIDTH
		var right_left := clampf(board_rect.end.x + DOCK_GAP, 0.0, size.x - EDGE_MARGIN - COLUMN_WIDTH) - size.x
		_enemies_box.offset_left = right_left
		_enemies_box.offset_right = right_left + COLUMN_WIDTH

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
		_turn_label.text = "%s's turn: pick an action, click any card as the target, then swap tiles" % character.display_name
	elif character.controller.is_remote():
		_turn_label.text = "%s is thinking..." % character.display_name
	else:
		_turn_label.text = "%s's turn..." % character.display_name
	_update_target_marks()

func _on_action_selected(character: Character, action: BattleAction) -> void:
	_update_target_marks()
	_refresh_charge()
	if not character.controller.is_human() and _battle.pending_target != null:
		_turn_label.text = "%s prepares to %s %s" % [character.display_name, action.display_name().to_lower(), _battle.pending_target.display_name]

func _on_target_selected(_target: Character) -> void:
	_update_target_marks()

func _on_score_awarded(_amount: int, _wave: int, _cell: GridCell, _entity: BoardEntity) -> void:
	if not visible or _battle == null or _battle.active_character == null:
		return
	var actor := _battle.active_character
	_cards[actor].set_power(_battle.power_of(actor, _ctx.score_tracker), _ctx.score_tracker.combo_factor())
	_refresh_charge()

func _on_action_resolved(action: CombatAction, damage: int, is_crit: bool) -> void:
	var target_card: CharacterCard = _cards[action.target]
	target_card.play_hit(damage, is_crit)
	if not action.target.is_alive():
		_update_target_marks()
	_turn_label.text = "%s hits %s for %d%s" % [action.actor.display_name, action.target.display_name, damage, "  CRIT!" if is_crit else ""]

func _on_character_left(character: Character) -> void:
	_cards[character].refresh()
	_update_target_marks()
	_turn_label.text = "%s left the game" % character.display_name

func _on_action_launched(actor: Character, target: Character, action: BattleAction) -> void:
	var intensity := _charge_intensity()
	# A self-cast keeps glowing until its burst; set_active(false) clears it at turn end.
	if target != actor:
		_cards[actor].set_charge(0.0, Color.WHITE)
	_fx.play_action(_cards[actor].get_global_rect(), _cards[target].get_global_rect(), BattleFx.color_for(action), PhaseResolveCombatAction.LAUNCH_SECONDS, intensity)

func _refresh_charge() -> void:
	var actor := _battle.active_character
	if actor != null and _battle.pending_action != null:
		_cards[actor].set_charge(_charge_intensity(), BattleFx.color_for(_battle.pending_action))

## One 0..1 scale for every power-driven visual (aura, bolt, burst, hit): the
## pending action's power relative to its target, 0 when there's none.
func _charge_intensity() -> float:
	var actor := _battle.active_character
	var power := _battle.power_of(actor, _ctx.score_tracker)
	if power <= 0:
		return 0.0
	var target := _battle.pending_target if _battle.pending_target != null else actor
	return clampf(MIN_CHARGE + (1.0 - MIN_CHARGE) * power / (target.max_hp * FULL_CHARGE_HP_SHARE), MIN_CHARGE, 1.0)


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
	if _battle.is_versus():
		var winners := _battle.allies if victory else _battle.enemies
		_result_label.text = "%s wins!" % " & ".join(PackedStringArray(winners.map(func(c: Character) -> String: return c.display_name)))
		_continue_button.text = "Rematch"
		# A rematch needs both players; the online one leaves through the main menu.
		_continue_button.visible = not _battle.is_online()
	else:
		_result_label.text = "Victory!" if victory else "%s wins!" % _battle.enemies[0].display_name
		_continue_button.text = "Next battle" if victory else "Retry"
	_overlay.visible = true

## Ends the battle screen with a message and only the way out (the opponent is gone).
func show_notice(text: String) -> void:
	_result_label.text = text
	_continue_button.visible = false
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

func _add_card(character: Character, box: BoxContainer) -> void:
	var card := CharacterCard.new()
	box.add_child(card)
	card.setup(character, _battle.actions)
	card.clicked.connect(_on_card_clicked)
	card.action_picked.connect(_on_action_picked)
	_cards[character] = card
	_fit_card(card)

func _apply_layout() -> void:
	_portrait = size.y > size.x
	if _portrait:
		_place_row(_enemies_box, false)
		_place_row(_allies_box, true)
		_set_offsets(_turn_label, 0.0, 1.0, EDGE_MARGIN, -MENU_BUTTON_CLEARANCE, 56.0, PORTRAIT_BANNER_BOTTOM)
	else:
		_place_column(_allies_box, true)
		_place_column(_enemies_box, false)
		_set_offsets(_turn_label, 0.5, 0.5, -400.0, 400.0, 16.0, 80.0)
	for card: CharacterCard in _cards.values():
		_fit_card(card)

func _place_column(box: BoxContainer, left: bool) -> void:
	box.vertical = true
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	box.offset_top = COLUMN_TOP
	box.offset_bottom = -COLUMN_BOTTOM_MARGIN
	var x := 0.0 if left else 1.0
	_set_offsets(box, x, x, EDGE_MARGIN if left else -EDGE_MARGIN - COLUMN_WIDTH, EDGE_MARGIN + COLUMN_WIDTH if left else -EDGE_MARGIN, box.offset_top, box.offset_bottom)

func _place_row(box: BoxContainer, bottom: bool) -> void:
	box.vertical = false
	var y := 1.0 if bottom else 0.0
	box.anchor_top = y
	box.anchor_bottom = y
	var top := -EDGE_MARGIN - ROW_HEIGHT if bottom else PORTRAIT_BANNER_BOTTOM
	_set_offsets(box, 0.0, 1.0, 8.0, -8.0, top, top + ROW_HEIGHT)

## Horizontal anchors + all offsets; vertical anchors are left to the caller.
static func _set_offsets(control: Control, anchor_left: float, anchor_right: float, left: float, right: float, top: float, bottom: float) -> void:
	control.anchor_left = anchor_left
	control.anchor_right = anchor_right
	control.offset_left = left
	control.offset_right = right
	control.offset_top = top
	control.offset_bottom = bottom

## Row cards hug the board (rows are docked to it), so an expanding active card grows away from it.
## Portrait rows share the width: full cards when they fit, else narrower
## compact ones (never below CharacterCard.COMPACT_WIDTH).
func _fit_card(card: CharacterCard) -> void:
	var count := card.get_parent().get_child_count()
	var share := (size.x - 16.0 - ROW_SEPARATION * (count - 1)) / count
	var compact := _portrait and share < CharacterCard.WIDTH
	card.set_compact(compact)
	if compact:
		card.custom_minimum_size.x = maxf(share, CharacterCard.COMPACT_WIDTH)
	var on_top_row := _portrait and card.get_parent() == _enemies_box
	card.size_flags_vertical = Control.SIZE_SHRINK_END if on_top_row else Control.SIZE_SHRINK_BEGIN

func _make_box() -> BoxContainer:
	var box := BoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(box)
	return box

func _build_turn_label() -> void:
	_turn_label = Label.new()
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 26)
	_turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_turn_label.add_theme_constant_override("outline_size", 6)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_turn_label)

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
	_continue_button.pressed.connect(func() -> void: continue_requested.emit(_battle.is_victory() and not _battle.is_versus()))
	box.add_child(_continue_button)
	var leave := Button.new()
	leave.text = "Main menu"
	leave.custom_minimum_size = Vector2(220, 44)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(leave)
