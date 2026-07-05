## Bottom-of-screen world editor UI: cell-kind dropdown, remove-cell button,
## and two tile dropdowns (normal/special), radio-selected across all four
## controls. Dropdown icons are rendered once from the real cell/Tile
## visuals (BoardView3D/TileView) in an offscreen SubViewport, so a new
## EditorCellCatalog/EditorTileCatalog entry needs no hand-drawn icon asset.
## IconViewport lives outside Panel (the part set_panel_visible hides) —
## hiding an ancestor stops a SubViewport from rendering, which would starve
## icon capture of a frame to read back.
class_name EditorToolbar
extends Control

signal cell_kind_selected(entry: EditorCellCatalog.Entry)
signal remove_cell_selected
signal tile_selected(entry: EditorTileCatalog.Entry)

@onready var _panel: Control = $Panel
@onready var _cell_kind_option: OptionButton = $Panel/Toolbar/CellKindOption
@onready var _remove_cell_button: Button = $Panel/Toolbar/RemoveCellButton
@onready var _normal_option: OptionButton = $Panel/Toolbar/NormalTilesOption
@onready var _special_option: OptionButton = $Panel/Toolbar/SpecialTilesOption
@onready var _icon_viewport: SubViewport = $IconViewport

var _tile_view := TileView.new()
var _cell_entries: Array[EditorCellCatalog.Entry] = []
var _normal_entries: Array[EditorTileCatalog.Entry] = []
var _special_entries: Array[EditorTileCatalog.Entry] = []

## item_selected only fires on an actual index change — re-picking a tool
## dropdown's already-selected entry while a different control (e.g. the
## cell-kind dropdown) is the active tool would then do nothing. id_pressed
## on the OptionButton's own popup fires on every click regardless, so it's
## used here instead (ids assigned == index, see setup()).
func _ready() -> void:
	_cell_kind_option.get_popup().id_pressed.connect(_on_cell_kind_selected)
	_remove_cell_button.pressed.connect(_on_remove_cell_pressed)
	_normal_option.get_popup().id_pressed.connect(_on_normal_tile_selected)
	_special_option.get_popup().id_pressed.connect(_on_special_tile_selected)

func set_panel_visible(visible_now: bool) -> void:
	_panel.visible = visible_now

func setup(cell_catalog: Array[EditorCellCatalog.Entry], tile_catalog: Array[EditorTileCatalog.Entry]) -> void:
	_cell_entries = cell_catalog
	_normal_entries.clear()
	_special_entries.clear()
	for entry: EditorTileCatalog.Entry in tile_catalog:
		if entry.category == EditorTileCatalog.Category.NORMAL:
			_normal_entries.append(entry)
		else:
			_special_entries.append(entry)

	_cell_kind_option.clear()
	for i in range(_cell_entries.size()):
		var entry: EditorCellCatalog.Entry = _cell_entries[i]
		var kind: CellKind = entry.factory.call()
		var scene: PackedScene = BoardView3D.CELL_SCENES_BY_VISUAL_KIND.get(kind.visual_kind(), BoardView3D.DEFAULT_CELL_SCENE)
		await _add_option_item(_cell_kind_option, entry.display_name, scene.instantiate(), i)

	await _populate_tiles(_normal_option, _normal_entries)
	await _populate_tiles(_special_option, _special_entries)
	_set_active_tool(Tool.CELL_KIND)

func _populate_tiles(option: OptionButton, entries: Array[EditorTileCatalog.Entry]) -> void:
	option.clear()
	for i in range(entries.size()):
		var entry: EditorTileCatalog.Entry = entries[i]
		if not entry.factory.is_valid():
			option.add_item(entry.display_name, i)  # the "erase" entry has nothing to render
			continue
		var tile: Tile = entry.factory.call()
		await _add_option_item(option, entry.display_name, _tile_view.build_node(tile), i)

## `id` is always the entry's index (see callers) — kept explicit rather than
## Godot's auto-incrementing default so id_pressed can index straight back
## into _cell_entries/_normal_entries/_special_entries.
func _add_option_item(option: OptionButton, display_name: String, preview_node: Node3D, id: int) -> void:
	var icon := await _capture_icon(preview_node)
	if icon != null:
		option.add_icon_item(icon, display_name, id)
	else:
		option.add_item(display_name, id)

func _capture_icon(node: Node3D) -> ImageTexture:
	_icon_viewport.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := _icon_viewport.get_texture().get_image()
	node.queue_free()
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

## Only one tool is ever active, but a dropdown's displayed text is its
## selected item's label — clearing selection on the other controls to show
## that would blank them out instead. Highlight the active one via tint
## instead, same idea as the remove-cell button's own pressed look.
enum Tool { CELL_KIND, REMOVE_CELL, NORMAL_TILE, SPECIAL_TILE }

const ACTIVE_TINT := Color(0.55, 0.85, 1.0)
const INACTIVE_TINT := Color(1.0, 1.0, 1.0)

func _set_active_tool(tool: Tool) -> void:
	_remove_cell_button.button_pressed = tool == Tool.REMOVE_CELL
	_cell_kind_option.modulate = ACTIVE_TINT if tool == Tool.CELL_KIND else INACTIVE_TINT
	_normal_option.modulate = ACTIVE_TINT if tool == Tool.NORMAL_TILE else INACTIVE_TINT
	_special_option.modulate = ACTIVE_TINT if tool == Tool.SPECIAL_TILE else INACTIVE_TINT

func _on_cell_kind_selected(id: int) -> void:
	_cell_kind_option.select(id)
	_set_active_tool(Tool.CELL_KIND)
	cell_kind_selected.emit(_cell_entries[id])

func _on_remove_cell_pressed() -> void:
	_set_active_tool(Tool.REMOVE_CELL)
	remove_cell_selected.emit()

func _on_normal_tile_selected(id: int) -> void:
	_normal_option.select(id)
	_set_active_tool(Tool.NORMAL_TILE)
	tile_selected.emit(_normal_entries[id])

func _on_special_tile_selected(id: int) -> void:
	_special_option.select(id)
	_set_active_tool(Tool.SPECIAL_TILE)
	tile_selected.emit(_special_entries[id])
