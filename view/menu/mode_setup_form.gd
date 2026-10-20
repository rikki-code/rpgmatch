## The setup page of one mode, built from its schema: the mode's stats, then a preset
## row (if any), plain settings and the advanced ones behind a toggle. Starts from the
## settings used last time. Picking a preset fills the values; editing a value
## switches the preset to Custom.
class_name ModeSetupForm
extends VBoxContainer

var _definition: ModeDefinition
var _schema: Array[SettingSpec]
var _settings: Dictionary
var _spins := {}  # StringName -> SpinBox
var _preset_option: OptionButton
var _advanced_toggle: Button

func setup(definition: ModeDefinition, profile: ProfileData) -> void:
	_definition = definition
	var stats := profile.stats_for(definition.id())
	_schema = definition.settings_schema(stats)
	_settings = definition.resolve_settings(profile.settings_for(definition.id()), stats)
	add_theme_constant_override("separation", 16)
	add_child(MenuKit.label(definition.title(), MenuKit.TITLE_FONT_SIZE))
	for spec in definition.stat_specs():
		add_child(MenuKit.stat_row(spec.label, stats.value_of(spec.key)))

	var bundles := definition.presets()
	if not bundles.is_empty():
		var labels: Array[String] = []
		for bundle in bundles:
			labels.append(bundle.label)
		labels.append("Custom")
		_preset_option = MenuKit.option(labels, _settings[&"preset"])
		_preset_option.item_selected.connect(_on_preset_selected)
		add_child(MenuKit.row("Difficulty", _preset_option))

	var advanced: Array[SettingSpec] = []
	for spec in _schema:
		if spec.min_value == spec.max_value:
			continue
		if spec.advanced:
			advanced.append(spec)
		else:
			_add_spin(self, spec)
	if advanced.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.visible = false
	for spec in advanced:
		_add_spin(box, spec)
	_advanced_toggle = MenuKit.button(self, "Advanced settings", _toggle_advanced.bind(box))
	add_child(box)

func make_config() -> RunConfig:
	for key: StringName in _spins:
		_settings[key] = int(_spins[key].value)
	return RunConfig.new(_definition, _settings)

func _add_spin(parent: Control, spec: SettingSpec) -> void:
	var spin := MenuKit.spin(parent, spec, _settings[spec.key])
	spin.value_changed.connect(func(_value: float) -> void: _mark_custom())
	_spins[spec.key] = spin

func _toggle_advanced(box: Control) -> void:
	box.visible = not box.visible
	_advanced_toggle.text = "Hide advanced settings" if box.visible else "Advanced settings"

func _on_preset_selected(index: int) -> void:
	var bundles := _definition.presets()
	_settings[&"preset"] = index
	if index >= bundles.size():
		return
	_settings.merge(bundles[index].values, true)
	for key: StringName in _spins:
		_spins[key].set_value_no_signal(_settings[key])

func _mark_custom() -> void:
	if _preset_option == null:
		return
	var custom := _definition.presets().size()
	_settings[&"preset"] = custom
	_preset_option.select(custom)
