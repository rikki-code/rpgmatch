## Top-right ☰ button + Esc toggle a pause menu (mode/editor, settings, reset, quit).
## Only emits signals; GameRoot owns what they do.
class_name GameMenu
extends Control

signal mode_selected(index: int)
signal editor_selected
## `packs` maps a PackCatalog category to the chosen option id.
signal settings_applied(params: WorldGenParams, packs: Dictionary)
signal reset_requested
signal quit_requested

## Large on purpose: the menu must be easy to hit on a phone.
const PANEL_WIDTH := 540.0
const FONT_SIZE := 30
const TITLE_FONT_SIZE := 44
const ROW_HEIGHT := 68.0
const OPEN_BUTTON_SIZE := 72.0

var _open_button: Button
var _dim: ColorRect
var _main_page: VBoxContainer
var _settings_page: VBoxContainer
var _mode_option: OptionButton
var _width_spin: SpinBox
var _height_spin: SpinBox
var _colors_spin: SpinBox
var _pits_spin: SpinBox
var _pack_options: Dictionary = {}  # category -> OptionButton
var _editor_item := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_set_open(false)

## The editor is listed last in the Mode dropdown, after the real GameModes.
func setup(mode_names: Array[String], mode_index: int, params: WorldGenParams) -> void:
	_mode_option.clear()
	for mode_name in mode_names:
		_mode_option.add_item(mode_name)
	_mode_option.add_item("Editor (R)")
	_editor_item = mode_names.size()
	_mode_option.select(mode_index)
	_width_spin.value = params.width
	_height_spin.value = params.height
	_colors_spin.value = params.color_count
	_pits_spin.value = params.pit_count

func show_selected(mode_index: int, editor_active: bool) -> void:
	_mode_option.select(_editor_item if editor_active else mode_index)

func hud_rects() -> Array[Rect2]:
	return [_open_button.get_global_rect()]

func is_open() -> bool:
	return _dim.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings_page.visible:
			_show_page(_main_page)
		else:
			_set_open(not is_open())
		get_viewport().set_input_as_handled()

func _set_open(open: bool) -> void:
	_dim.visible = open
	_open_button.visible = not open
	get_tree().paused = open
	_show_page(_main_page)

func _show_page(page: Control) -> void:
	_main_page.visible = page == _main_page
	_settings_page.visible = page == _settings_page

func _build() -> void:
	_open_button = Button.new()
	# An icon, not a glyph: web builds have no system font fallback for symbols.
	_open_button.icon = load(PackPaths.UI_PACK + "menu_icon.svg")
	_open_button.expand_icon = true
	_open_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_open_button.anchor_left = 1.0
	_open_button.anchor_right = 1.0
	_open_button.offset_left = -OPEN_BUTTON_SIZE - 12.0
	_open_button.offset_right = -12.0
	_open_button.offset_top = 12.0
	_open_button.offset_bottom = 12.0 + OPEN_BUTTON_SIZE
	_open_button.pressed.connect(func() -> void: _set_open(true))
	add_child(_open_button)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	var panel_theme := Theme.new()
	panel_theme.default_font_size = FONT_SIZE
	panel.theme = panel_theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.065, 0.11, 1.0)
	style.border_color = Color(0.55, 0.42, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var pages := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pages.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(pages)

	_main_page = _page(pages, "Menu")
	_mode_option = OptionButton.new()
	_mode_option.item_selected.connect(_on_mode_item_selected)
	# The dropdown is its own popup window, outside the panel theme.
	_mode_option.get_popup().add_theme_font_size_override("font_size", FONT_SIZE)
	_main_page.add_child(_row("Mode", _mode_option))
	_button(_main_page, "Resume", func() -> void: _set_open(false))
	_button(_main_page, "Settings", func() -> void: _show_page(_settings_page))
	_button(_main_page, "Reset board", func() -> void: reset_requested.emit())
	_button(_main_page, "Quit", func() -> void: quit_requested.emit())

	_settings_page = _page(pages, "Settings")
	_width_spin = _spin(_settings_page, "Width", 4, 16)
	_height_spin = _spin(_settings_page, "Height", 4, 12)
	_colors_spin = _spin(_settings_page, "Tile colors", 3, BoardGraph.MAX_COLORS)
	_pits_spin = _spin(_settings_page, "Holes", 0, 40)
	_pack_option(PackCatalog.TILES, "Tiles")
	_pack_option(PackCatalog.BOARD, "Board")
	_button(_settings_page, "Apply (new board)", _apply_settings)
	_button(_settings_page, "Back", func() -> void: _show_page(_main_page))

func _apply_settings() -> void:
	var params := WorldGenParams.new()
	params.width = int(_width_spin.value)
	params.height = int(_height_spin.value)
	params.color_count = int(_colors_spin.value)
	params.pit_count = int(_pits_spin.value)
	var packs := {}
	for category: StringName in _pack_options:
		var option: OptionButton = _pack_options[category]
		packs[category] = PackCatalog.options(category)[option.selected]["id"]
	settings_applied.emit(params, packs)

func _on_mode_item_selected(index: int) -> void:
	_set_open(false)
	if index == _editor_item:
		editor_selected.emit()
	else:
		mode_selected.emit(index)

func _page(parent: Control, title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	parent.add_child(page)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	page.add_child(label)
	return page

func _row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size = Vector2(220.0, ROW_HEIGHT)
	row.add_child(control)
	return row

func _button(parent: Control, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = ROW_HEIGHT
	button.pressed.connect(on_pressed)
	parent.add_child(button)

func _pack_option(category: StringName, caption: String) -> void:
	var option := OptionButton.new()
	var choices := PackCatalog.options(category)
	for i in range(choices.size()):
		option.add_item(choices[i]["name"])
		if choices[i]["id"] == PackCatalog.selected_id(category):
			option.select(i)
	option.get_popup().add_theme_font_size_override("font_size", FONT_SIZE)
	_pack_options[category] = option
	_settings_page.add_child(_row(caption, option))

func _spin(parent: Control, caption: String, min_value: int, max_value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.rounded = true
	parent.add_child(_row(caption, spin))
	return spin
