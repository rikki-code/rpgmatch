## Builders shared by the start screen and the pause menu: large, touch-sized, built in code.
class_name MenuKit
extends RefCounted

const FONT_SIZE := 30
const TITLE_FONT_SIZE := 44
const ROW_HEIGHT := 68.0

## Only the default font size; everything else still comes from the project theme.
static func big_text_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	return theme

static func label(text: String, font_size := FONT_SIZE) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size)
	return result

static func stat_row(caption: String, value: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(value_label)
	return box

static func page(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	parent.add_child(box)
	box.add_child(label(title, TITLE_FONT_SIZE))
	return box

static func row(caption: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(caption_label)
	control.custom_minimum_size = Vector2(220.0, ROW_HEIGHT)
	box.add_child(control)
	return box

static func button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = ROW_HEIGHT
	result.pressed.connect(on_pressed)
	parent.add_child(result)
	return result

static func spin(parent: Control, spec: SettingSpec, value: int) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = spec.min_value
	box.max_value = spec.max_value
	box.rounded = true
	box.suffix = spec.suffix
	box.value = value
	parent.add_child(row(spec.label, box))
	return box

## The dropdown is its own popup window, outside the panel theme.
static func option(items: Array[String], selected: int) -> OptionButton:
	var result := OptionButton.new()
	for item in items:
		result.add_item(item)
	result.select(selected)
	result.get_popup().add_theme_font_size_override("font_size", FONT_SIZE)
	return result
