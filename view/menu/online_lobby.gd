## Multiplayer page of the start screen: enter a name, then either wait for an
## opponent or join one of the players already waiting. All networking is Net's;
## this only shows its state and emits when a match is agreed.
class_name OnlineLobby
extends VBoxContainer

signal match_ready(config: RunConfig)
signal name_committed(player_name: String)

const DEFAULT_LEVEL := 3

var _name_edit: LineEdit
var _level_spin: SpinBox
var _host_button: Button
var _status: Label
var _list: VBoxContainer

func setup(player_name: String) -> void:
	add_theme_constant_override("separation", 16)
	add_child(MenuKit.label("Multiplayer", MenuKit.TITLE_FONT_SIZE))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = ProfileData.DEFAULT_PLAYER_NAME
	_name_edit.max_length = NetDirector.MAX_NAME_LENGTH
	_name_edit.text = player_name
	_name_edit.focus_exited.connect(_commit_name)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _commit_name())
	add_child(MenuKit.row("Name", _name_edit))
	_level_spin = MenuKit.spin(self, SettingSpec.new(&"level", "Level (if you host)", 1, BattleDefinition.MAX_LEVEL, DEFAULT_LEVEL), DEFAULT_LEVEL)
	_host_button = MenuKit.button(self, "Wait for an opponent", _on_host_pressed)
	_status = MenuKit.label("", 26)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	add_child(MenuKit.label("Waiting players", 34))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	add_child(_list)

	Net.status_changed.connect(func(text: String) -> void: _status.text = text)
	Net.lobby_changed.connect(_refresh)
	Net.match_ready.connect(func(config: RunConfig) -> void: match_ready.emit(config))
	Net.browse()
	_refresh()

func _on_host_pressed() -> void:
	if Net.is_hosting():
		Net.cancel_host()
	else:
		_commit_name()
		Net.host(_name_edit.text, int(_level_spin.value))
	_refresh()

func _on_join_pressed(host_id: String) -> void:
	_commit_name()
	Net.join(host_id, _name_edit.text)

func _commit_name() -> void:
	var player_name := _name_edit.text.strip_edges()
	if player_name == "":
		player_name = ProfileData.DEFAULT_PLAYER_NAME
		_name_edit.text = player_name
	name_committed.emit(player_name)

func _refresh() -> void:
	var hosting := Net.is_hosting()
	_host_button.text = "Stop waiting" if hosting else "Wait for an opponent"
	_level_spin.editable = not hosting
	for child in _list.get_children():
		child.queue_free()
	var entries := Net.lobby()
	if entries.is_empty():
		_list.add_child(MenuKit.label("Nobody is waiting yet", 26))
	for entry in entries:
		var button := MenuKit.button(_list, "%s   (level %d)" % [entry["name"], entry["level"]], _on_join_pressed.bind(entry["id"]))
		button.disabled = hosting
