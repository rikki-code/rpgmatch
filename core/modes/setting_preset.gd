## A named bundle of setting values (a difficulty). May also carry keys the
## form never shows, e.g. bonus spawn chances.
class_name SettingPreset
extends RefCounted

var label: String
var values: Dictionary

func _init(p_label: String, p_values: Dictionary) -> void:
	label = p_label
	values = p_values
