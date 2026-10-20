## The sound part of a settings page: three volume sliders and the audio pack choice.
## Shared by the pause menu and the start screen, which each decide what a pack pick does.
class_name SoundSettings
extends RefCounted

const VOLUMES := [
	[AudioSettings.MASTER, "Master"],
	[AudioSettings.MUSIC, "Music"],
	[AudioSettings.SFX, "Effects"],
]

static func add_to(page: Control, on_pack_picked: Callable) -> void:
	for entry: Array in VOLUMES:
		var key: StringName = entry[0]
		var slider := MenuKit.slider(AudioSettings.volume(key))
		slider.value_changed.connect(func(value: float) -> void: Audio.set_volume(key, value))
		page.add_child(MenuKit.row(entry[1], slider))
	var choices := PackCatalog.options(PackCatalog.AUDIO)
	var names: Array[String] = []
	var selected := 0
	for i in range(choices.size()):
		names.append(choices[i]["name"])
		if choices[i]["id"] == PackCatalog.selected_id(PackCatalog.AUDIO):
			selected = i
	var option := MenuKit.option(names, selected)
	option.item_selected.connect(func(index: int) -> void: on_pack_picked.call(choices[index]["id"]))
	page.add_child(MenuKit.row("Sound pack", option))
