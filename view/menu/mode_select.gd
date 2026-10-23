## Start screen: a button per mode, and for modes with settings a setup page
## before the start. Only emits; MenuRoot owns what happens next.
class_name ModeSelect
extends Control

signal start_requested(config: RunConfig)
signal continue_requested(run: RunSave)
signal quit_requested
signal sound_pack_selected(id: String)
signal player_name_changed(player_name: String)

const CONTENT_WIDTH := 760.0
const LOGO_HEIGHT := 240.0

var _select_page: VBoxContainer
var _setup_holder: VBoxContainer
## Pinned under the scrolling form so Start never leaves the screen.
var _footer: CenterContainer
var _profile: ProfileData
var _runs: Dictionary  # StringName -> RunSave

func setup(definitions: Array[ModeDefinition], profile: ProfileData, runs: Dictionary, can_quit: bool) -> void:
	_profile = profile
	_runs = runs
	theme = MenuKit.big_text_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.035, 0.06)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_footer = CenterContainer.new()
	layout.add_child(_footer)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = CONTENT_WIDTH
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)

	_select_page = VBoxContainer.new()
	_select_page.add_theme_constant_override("separation", 20)
	column.add_child(_select_page)
	_setup_holder = VBoxContainer.new()
	column.add_child(_setup_holder)

	_select_page.add_child(_logo())
	for definition in definitions:
		MenuKit.button(_select_page, definition.title(), _on_play.bind(definition))
	MenuKit.button(_select_page, "Multiplayer", _show_online)
	MenuKit.button(_select_page, "Settings", _show_settings)
	if can_quit:
		MenuKit.button(_select_page, "Quit", func() -> void: quit_requested.emit())
	_show_select()

func _logo() -> Control:
	var texture := load(PackPaths.UI_PACK + "logo.svg") as Texture2D
	if texture == null:
		return MenuKit.label("rpgmatch", 72)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size.y = LOGO_HEIGHT
	return rect

func _on_play(definition: ModeDefinition) -> void:
	if definition.settings_schema(_profile.stats_for(definition.id())).is_empty() and not _runs.has(definition.id()):
		start_requested.emit(RunConfig.defaults(definition))
	else:
		_show_setup(definition)

func _show_select() -> void:
	_clear(_setup_holder)
	_clear(_footer)
	_setup_holder.visible = false
	_select_page.visible = true

func _clear(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()

func _show_settings() -> void:
	_select_page.visible = false
	_setup_holder.visible = true
	var page := MenuKit.page(_setup_holder, "Settings")
	SoundSettings.add_to(page, func(id: String) -> void: sound_pack_selected.emit(id))
	var padded := MarginContainer.new()
	padded.add_theme_constant_override("margin_bottom", 28)
	_footer.add_child(padded)
	var back := MenuKit.button(padded, "Back", _show_select)
	back.custom_minimum_size.x = CONTENT_WIDTH

func _show_online() -> void:
	_select_page.visible = false
	_setup_holder.visible = true
	var lobby := OnlineLobby.new()
	_setup_holder.add_child(lobby)
	lobby.setup(_profile.player_name)
	lobby.match_ready.connect(func(config: RunConfig) -> void: start_requested.emit(config))
	lobby.name_committed.connect(func(player_name: String) -> void: player_name_changed.emit(player_name))
	var padded := MarginContainer.new()
	padded.add_theme_constant_override("margin_bottom", 28)
	_footer.add_child(padded)
	var back := MenuKit.button(padded, "Back", func() -> void:
		Net.leave()
		_show_select()
	)
	back.custom_minimum_size.x = CONTENT_WIDTH

func _show_setup(definition: ModeDefinition) -> void:
	_select_page.visible = false
	_setup_holder.visible = true
	var form := ModeSetupForm.new()
	_setup_holder.add_child(form)
	form.setup(definition, _profile)
	var padded := MarginContainer.new()
	padded.add_theme_constant_override("margin_bottom", 28)
	_footer.add_child(padded)
	var buttons := HBoxContainer.new()
	buttons.custom_minimum_size.x = CONTENT_WIDTH
	buttons.add_theme_constant_override("separation", 16)
	padded.add_child(buttons)
	var back := MenuKit.button(buttons, "Back", _show_select)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var run: RunSave = _runs.get(definition.id())
	if run != null:
		var resume := MenuKit.button(buttons, "Continue", func() -> void: continue_requested.emit(run))
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start := MenuKit.button(buttons, "New game" if run != null else "Start", func() -> void: start_requested.emit(form.make_config()))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
