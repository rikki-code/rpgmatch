## Top-right ☰ button + Esc toggle a pause menu (resume, pack settings, restart, exit).
## Only emits signals; GameRoot owns what they do.
class_name GameMenu
extends Control

signal pack_selected(category: StringName, id: String)
signal restart_requested
signal exit_requested

## Large on purpose: the menu must be easy to hit on a phone.
const PANEL_WIDTH := 540.0
const OPEN_BUTTON_SIZE := 72.0

var _open_button: Button
var _dim: ColorRect
var _main_page: VBoxContainer
var _settings_page: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_set_open(false)

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
	if is_node_ready() and open != _dim.visible:
		Audio.play(&"menu_open" if open else &"menu_close")
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
	panel.theme = MenuKit.big_text_theme()
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

	_main_page = MenuKit.page(pages, "Menu")
	MenuKit.button(_main_page, "Resume", func() -> void: _set_open(false))
	MenuKit.button(_main_page, "Settings", func() -> void: _show_page(_settings_page))
	MenuKit.button(_main_page, "Restart", func() -> void: restart_requested.emit())
	MenuKit.button(_main_page, "Main menu", func() -> void: exit_requested.emit())

	_settings_page = MenuKit.page(pages, "Settings")
	_pack_option(PackCatalog.TILES, "Tiles")
	_pack_option(PackCatalog.BOARD, "Board")
	SoundSettings.add_to(_settings_page, func(id: String) -> void: pack_selected.emit(PackCatalog.AUDIO, id))
	MenuKit.button(_settings_page, "Back", func() -> void: _show_page(_main_page))

## A pick applies at once: the board swaps models in place, no new level.
func _pack_option(category: StringName, caption: String) -> void:
	var choices := PackCatalog.options(category)
	var names: Array[String] = []
	var selected := 0
	for i in range(choices.size()):
		names.append(choices[i]["name"])
		if choices[i]["id"] == PackCatalog.selected_id(category):
			selected = i
	var option := MenuKit.option(names, selected)
	option.item_selected.connect(func(index: int) -> void: pack_selected.emit(category, choices[index]["id"]))
	_settings_page.add_child(MenuKit.row(caption, option))
