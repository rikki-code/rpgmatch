## One line of a mode's stats readout: which ModeStats key and what to call it.
class_name StatSpec
extends RefCounted

var key: StringName
var label: String

func _init(p_key: StringName, p_label: String) -> void:
	key = p_key
	label = p_label
