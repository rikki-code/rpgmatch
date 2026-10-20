## Active-quest cards: tile icon (rendered like the editor toolbar's dropdown
## icons, see EditorToolbar) + progress number underneath, one per quest.
## Docked to the board: a column on its right (landscape) or a row below it
## (portrait).
class_name QuestHud
extends BoxContainer

const EDGE_MARGIN := 16.0
const TOP := 64.0
const DOCK_GAP := 12.0

@onready var _icon_viewport: SubViewport = $IconViewport

var _tile_view := TileView.new()
var _icon_cache: Dictionary = {}  # StringName -> ImageTexture
var _cards: Dictionary = {}  # QuestProgress -> Control
var _counts: Dictionary = {}  # QuestProgress -> Label
## Multiple _add_card calls can fire in the same frame (initial batch, or
## several quests completing off one blast) — this serializes captures so
## only one tile ever sits in the shared IconViewport at a time.
var _icon_capture_busy := false

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_orientation)
	_apply_orientation()

func _apply_orientation() -> void:
	vertical = not _portrait()

## Reserved band at the screen edge it docks from (GameRoot._free_screen_rect).
func hud_rects() -> Array[Rect2]:
	var screen := get_viewport_rect().size
	if _portrait():
		return [Rect2(Vector2((screen.x - size.x) / 2.0, screen.y - EDGE_MARGIN - size.y), size)]
	return [Rect2(Vector2(screen.x - EDGE_MARGIN - size.x, TOP), size)]

func dock_to_board(board_rect: Rect2, _spawn_lane: float) -> void:
	var screen := get_viewport_rect().size
	if _portrait():
		position = Vector2(board_rect.get_center().x - size.x / 2.0, minf(board_rect.end.y + DOCK_GAP, screen.y - EDGE_MARGIN - size.y))
	else:
		position = Vector2(minf(board_rect.end.x + DOCK_GAP, screen.x - EDGE_MARGIN - size.x), board_rect.position.y)

func _portrait() -> bool:
	var screen := get_viewport_rect().size
	return screen.y > screen.x

func setup(quest_manager: QuestManager) -> void:
	for quest in quest_manager.active_quests:
		_add_card(quest)
	quest_manager.quest_added.connect(_add_card)
	quest_manager.quest_progress_changed.connect(_update_card)
	quest_manager.quest_completed.connect(_on_completed)

func _add_card(quest: QuestProgress) -> void:
	var card := VBoxContainer.new()
	card.tooltip_text = quest.definition.display_name
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(icon)
	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(count_label)
	add_child(card)
	_cards[quest] = card
	_counts[quest] = count_label
	_update_card(quest)
	var texture := await _get_icon(quest.definition.target_kind_id)
	if texture != null and _counts.has(quest):
		icon.texture = texture

func reskin() -> void:
	_tile_view.dispose()
	_tile_view = TileView.new()
	_icon_cache.clear()
	for quest: QuestProgress in _cards.keys():
		if not _cards.has(quest):
			continue
		var icon: TextureRect = _cards[quest].get_child(0)
		var texture := await _get_icon(quest.definition.target_kind_id)
		if texture != null and is_instance_valid(icon):
			icon.texture = texture

func _update_card(quest: QuestProgress) -> void:
	var label: Label = _counts.get(quest)
	if label != null:
		label.text = "%d/%d" % [quest.current_count, quest.definition.target_count]

func _on_completed(quest: QuestProgress) -> void:
	var card: Control = _cards.get(quest)
	if card == null:
		return
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(card, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		_cards.erase(quest)
		_counts.erase(quest)
		card.queue_free()
	)

func _get_icon(kind: StringName) -> ImageTexture:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	while _icon_capture_busy:
		await get_tree().process_frame
	_icon_capture_busy = true
	var texture: ImageTexture = null
	var tile := _tile_for_kind(kind)
	if tile != null:
		var node := _tile_view.build_node(tile)
		_icon_viewport.add_child(node)
		await get_tree().process_frame
		await get_tree().process_frame
		var image := _icon_viewport.get_texture().get_image()
		node.queue_free()
		if image != null:
			texture = ImageTexture.create_from_image(image)
			_icon_cache[kind] = texture
	_icon_capture_busy = false
	return texture

func _tile_for_kind(kind: StringName) -> Tile:
	var kind_str := String(kind)
	if kind_str.begins_with("color_"):
		return Tile.make_normal(int(kind_str.substr(6)))
	match kind:
		&"bomb":
			return Tile.make_bomb()
		&"arrow_blaster":
			return Tile.make_arrow_blaster(ArrowBlasterCore.Axis.ROW)
		&"prism":
			return Tile.make_prism()
	return null
