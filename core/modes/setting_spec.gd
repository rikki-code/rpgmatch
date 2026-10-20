## One integer knob of a mode's setup form; the form is built from a list of these.
class_name SettingSpec
extends RefCounted

var key: StringName
var label: String
var min_value: int
var max_value: int
var default_value: int
var suffix: String
## Tucked behind the form's Advanced toggle.
var advanced := false

func _init(p_key: StringName, p_label: String, p_min: int, p_max: int, p_default: int, p_suffix := "") -> void:
	key = p_key
	label = p_label
	min_value = p_min
	max_value = p_max
	default_value = p_default
	suffix = p_suffix

func as_advanced() -> SettingSpec:
	advanced = true
	return self
