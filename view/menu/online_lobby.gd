## Multiplayer page of the start screen: enter a name, then create a room or join one of
## the open rooms; inside a room the players are listed and the host starts the match.
## All networking is Net's; this only shows its state and emits when a match is agreed.
class_name OnlineLobby
extends VBoxContainer

signal match_ready(config: RunConfig)
signal name_committed(player_name: String)

const DEFAULT_LEVEL := 3

var _name_edit: LineEdit
var _status: Label
var _browse_box: VBoxContainer
var _level_spin: SpinBox
var _rooms: VBoxContainer
var _room_box: VBoxContainer
var _room_title: Label
var _players: VBoxContainer
var _start_button: Button

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
	_status = MenuKit.label("", 26)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_browse_box = _section()
	_level_spin = MenuKit.spin(_browse_box, SettingSpec.new(&"level", "Level (if you host)", 1, BattleDefinition.MAX_LEVEL, DEFAULT_LEVEL), DEFAULT_LEVEL)
	MenuKit.button(_browse_box, "Create room", _on_create_pressed)
	_browse_box.add_child(MenuKit.label("Open rooms", 34))
	_rooms = VBoxContainer.new()
	_rooms.add_theme_constant_override("separation", 12)
	_browse_box.add_child(_rooms)

	_room_box = _section()
	_room_title = MenuKit.label("", 34)
	_room_box.add_child(_room_title)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 8)
	_room_box.add_child(_players)
	_start_button = MenuKit.button(_room_box, "Start", Net.start_match)
	MenuKit.button(_room_box, "Leave room", Net.leave_room)

	Net.status_changed.connect(func(text: String) -> void: _status.text = text)
	Net.lobby_changed.connect(_refresh)
	Net.room_changed.connect(_refresh)
	Net.match_ready.connect(func(config: RunConfig) -> void: match_ready.emit(config))
	Net.browse()
	_refresh()

func _section() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	return box

func _on_create_pressed() -> void:
	_commit_name()
	Net.host(_name_edit.text, int(_level_spin.value))

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
	var in_room := Net.in_room()
	_browse_box.visible = not in_room
	_room_box.visible = in_room
	_name_edit.editable = not in_room
	if in_room:
		_refresh_room()
	else:
		_refresh_rooms()

func _refresh_rooms() -> void:
	_clear(_rooms)
	var entries := Net.lobby()
	if entries.is_empty():
		_rooms.add_child(MenuKit.label("No open rooms yet", 26))
	for entry in entries:
		var button := MenuKit.button(_rooms, "%s   (level %d, %d/%d)" % [entry["name"], entry["level"], entry["count"], NetDirector.MAX_PLAYERS], _on_join_pressed.bind(entry["id"]))
		button.disabled = entry["count"] >= NetDirector.MAX_PLAYERS

func _refresh_room() -> void:
	var players := Net.room_players()
	_room_title.text = "Room, level %d   (%d/%d)" % [Net.room_level(), players.size(), NetDirector.MAX_PLAYERS]
	_clear(_players)
	for seat in players.size():
		var team := "Hero team" if seat % 2 == 0 else "Devil team"
		var host_mark := " (host)" if seat == 0 else ""
		_players.add_child(MenuKit.label("%s%s   %s" % [players[seat]["name"], host_mark, team], 28))
	_start_button.visible = Net.is_hosting()
	_start_button.disabled = not Net.can_start()
	if Net.is_hosting() and not Net.can_start():
		_status.text = "Waiting for players..."
	elif not Net.is_hosting():
		_status.text = "Waiting for the host to start..."
	else:
		_status.text = ""

func _clear(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()
