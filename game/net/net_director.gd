## Online rooms and the wire to the other players, autoloaded as `Net`.
##
## There is no game server: everybody connects to a public MQTT broker (MqttClient) that
## only relays small JSON messages. A host opens a room and announces it on a lobby topic,
## guests join through the host's game topic, the host starts the match, and from then on
## every client runs the same deterministic game and only exchanges moves (see OnlineSync).
## Nothing is stored on the broker.
class_name NetDirector
extends Node

signal status_changed(text: String)
signal lobby_changed
## The room (its players, or being in one at all) changed.
signal room_changed
## The match is agreed: start the game scene with this config.
signal match_ready(config: RunConfig)
## A message of another player for the running game (see attach_game); "s" is the sender's seat.
signal game_message(message: Dictionary)
## Our own link to the others is gone: the match cannot go on here.
signal connection_lost(reason: String)

enum Mode { IDLE, BROWSING, HOSTING, JOINING, ROOM, PLAYING }

const BROKER_URLS: Array[String] = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
]
## Topics are public: anyone on the broker can read them, so a distinctive prefix keeps other users out of ours.
const ROOT := "rpgmatch-pvp/v1/"
const LOBBY_TOPIC := ROOT + "lobby"
const WHO_TOPIC := ROOT + "who"
const MAX_NAME_LENGTH := 16
const MIN_PLAYERS := 2
const MAX_PLAYERS := 6
const ENTRY_TTL_MSEC := 10000
const HOST_BEAT_MSEC := 4000
const JOIN_TIMEOUT_MSEC := 8000
const ROOM_SILENCE_MSEC := 15000
const PING_MSEC := 3000
const SILENCE_MSEC := 25000
## A guest that missed the start message gets it again from the first pings.
const START_REPEATS := 3
## A game message nobody confirmed yet is sent again this often.
const RESEND_MSEC := 1000

var my_id := ""
var _mode := Mode.IDLE
var _client: MqttClient
var _retired: Array[MqttClient] = []
var _url_index := 0
var _subscribed := {}  # topic -> true, for the current connection
var _entries := {}  # host id -> {"id", "name", "level", "count", "seen"}
var _name := ""
var _level := 1
var _host_id := ""
## The room's players in seat order, host first: {"id", "name"}.
var _players: Array[Dictionary] = []
var _start_message := {}
var _start_repeats := 0
var _last_room_msec := 0
var _last_rx := {}  # player id -> msec of its last message, while playing
var _next_beat_msec := 0
var _join_deadline_msec := 0
var _next_ping_msec := 0
## Reliable game messages: ours are numbered and kept until everybody confirmed them,
## theirs are accepted in order only (a QoS 0 publish can get lost).
var _tx_seq := 0
var _sent: Array[Dictionary] = []
var _acked := {}  # player id -> our highest message it confirmed
var _rx_seq := {}  # player id -> its highest message we accepted
var _next_resend_msec := 0
var _listening := false
var _inbox: Array[Dictionary] = []

func _ready() -> void:
	# The pause menu must not freeze the connection.
	process_mode = Node.PROCESS_MODE_ALWAYS
	my_id = "%08x%08x" % [randi(), randi()]

## Rooms waiting for players, as {"id", "name", "level", "count"}.
func lobby() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries.values():
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return result

func is_hosting() -> bool:
	return _mode == Mode.HOSTING

func in_room() -> bool:
	return _mode == Mode.HOSTING or _mode == Mode.ROOM

func room_players() -> Array[Dictionary]:
	return _players

func room_level() -> int:
	return _level

func can_start() -> bool:
	return _mode == Mode.HOSTING and _players.size() >= MIN_PLAYERS

func browse() -> void:
	_set_mode(Mode.BROWSING)

func host(player_name: String, level: int) -> void:
	_name = _clean_name(player_name)
	_level = level
	_players = [{"id": my_id, "name": _name}]
	_set_mode(Mode.HOSTING)
	room_changed.emit()

func join(host_id: String, player_name: String) -> void:
	_name = _clean_name(player_name)
	_host_id = host_id
	_set_mode(Mode.JOINING)

## The host closes the room (everybody is sent out), a guest walks out of it.
func leave_room() -> void:
	match _mode:
		Mode.HOSTING:
			_close_room()
		Mode.ROOM:
			_send_raw({"t": "leave"})
			_to_browsing("")

## The host starts the match with whoever is in the room.
func start_match() -> void:
	if not can_start():
		return
	var seed_value := randi_range(1, 2000000000)
	_start_message = {"f": my_id, "t": "start", "seed": seed_value, "level": _level, "players": _players}
	_start_repeats = START_REPEATS
	_publish(_game_topic(my_id), _start_message)
	_publish_lobby({"id": my_id, "gone": true})
	_begin_match(0, seed_value, _level)

## Drops out of lobby, room or match and closes the connection.
func leave() -> void:
	match _mode:
		Mode.HOSTING:
			_publish_lobby({"id": my_id, "gone": true})
			_publish(_game_topic(my_id), {"f": my_id, "t": "closed"})
		Mode.ROOM:
			_send_raw({"t": "leave"})
		Mode.PLAYING:
			send_game({"t": "bye"})
	if _client != null:
		_client.close()
		_retired.append(_client)
		_client = null
	_subscribed.clear()
	_entries.clear()
	_inbox.clear()
	_players.clear()
	_last_rx.clear()
	_sent.clear()
	_start_repeats = 0
	_listening = false
	_host_id = ""
	_mode = Mode.IDLE

## The running game starts listening: returns what the others sent while the scene loaded.
func attach_game() -> Array[Dictionary]:
	_listening = true
	var pending := _inbox.duplicate()
	_inbox.clear()
	return pending

## A message of the running game, resent until every other player confirmed it.
## Between two rounds the game scene is gone for a moment: what comes in waits for the next one.
func detach_game(unplayed: Array[Dictionary]) -> void:
	_listening = false
	var merged: Array[Dictionary] = []
	merged.append_array(unplayed)
	merged.append_array(_inbox)
	_inbox = merged

## A message of the running game, resent until every other player confirmed it.
func send_game(message: Dictionary) -> void:
	_tx_seq += 1
	var numbered := message.duplicate()
	numbered["n"] = _tx_seq
	_sent.append(numbered)
	_send_raw(numbered)

func _send_raw(message: Dictionary) -> void:
	if _host_id == "":
		return
	message["f"] = my_id
	_publish(_game_topic(_host_id), message)

func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()
	for client in _retired:
		client.poll()
	_retired = _retired.filter(func(client: MqttClient) -> bool: return client.is_alive())
	var now := Time.get_ticks_msec()
	match _mode:
		Mode.BROWSING:
			_expire_entries(now)
		Mode.HOSTING:
			if now >= _next_beat_msec and _client != null and _client.is_ready():
				_next_beat_msec = now + HOST_BEAT_MSEC
				_publish_entry()
				_broadcast_room()
		Mode.JOINING:
			if _join_deadline_msec != 0 and now >= _join_deadline_msec:
				_to_browsing("No answer from the host")
		Mode.ROOM:
			if now - _last_room_msec > ROOM_SILENCE_MSEC:
				_to_browsing("The host disappeared")
		Mode.PLAYING:
			if now >= _next_ping_msec:
				_next_ping_msec = now + PING_MSEC
				_send_raw({"t": "ping"})
				if _start_repeats > 0:
					_start_repeats -= 1
					_publish(_game_topic(my_id), _start_message)
			if now >= _next_resend_msec:
				_next_resend_msec = now + RESEND_MSEC
				_resend_unconfirmed()
			_drop_silent_players(now)

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_join_deadline_msec = 0
	if mode == Mode.JOINING:
		_join_deadline_msec = Time.get_ticks_msec() + JOIN_TIMEOUT_MSEC
	if _client != null and _client.is_ready():
		_enter_mode()
	elif _client == null:
		_url_index = 0
		_connect()
		status_changed.emit("Connecting...")

func _connect() -> void:
	_subscribed.clear()
	_client = MqttClient.new()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.message_received.connect(_on_message)
	_client.open(BROKER_URLS[_url_index], "rpgm-" + my_id)

func _on_connected() -> void:
	_enter_mode()

func _on_disconnected(was_connected: bool) -> void:
	_client = null
	if was_connected:
		if _mode == Mode.PLAYING:
			_lose_connection("Connection lost")
		else:
			_mode = Mode.IDLE
			_players.clear()
			status_changed.emit("Connection lost")
			room_changed.emit()
		return
	_url_index += 1
	if _url_index < BROKER_URLS.size():
		_connect()
		return
	_mode = Mode.IDLE
	_players.clear()
	status_changed.emit("Can't reach the server. Check your internet connection")
	room_changed.emit()

## Runs once the connection is up and again on every mode change.
func _enter_mode() -> void:
	_subscribe(LOBBY_TOPIC)
	match _mode:
		Mode.BROWSING:
			status_changed.emit("")
			if not _entries.is_empty():
				_entries.clear()
				lobby_changed.emit()
			_publish(WHO_TOPIC, {"id": my_id})
		Mode.HOSTING:
			_subscribe(WHO_TOPIC)
			_subscribe(_game_topic(my_id))
			_host_id = my_id
			_next_beat_msec = Time.get_ticks_msec() + HOST_BEAT_MSEC
			_publish_entry()
			status_changed.emit("")
		Mode.JOINING:
			_subscribe(_game_topic(_host_id))
			_publish(_game_topic(_host_id), {"f": my_id, "t": "join", "name": _name})
			status_changed.emit("Joining...")

func _subscribe(topic: String) -> void:
	if not _subscribed.has(topic):
		_subscribed[topic] = true
		_client.subscribe(topic)

func _on_message(topic: String, payload: PackedByteArray) -> void:
	var data: Variant = JSON.parse_string(payload.get_string_from_utf8())
	if not (data is Dictionary):
		return
	if topic == LOBBY_TOPIC:
		_on_lobby_message(data)
	elif topic == WHO_TOPIC:
		if _mode == Mode.HOSTING and data.get("id") != my_id:
			_publish_entry()
	elif _host_id != "" and topic == _game_topic(_host_id) and data.get("f", "") != my_id:
		_on_game_topic_message(data)

func _on_lobby_message(data: Dictionary) -> void:
	var id: String = str(data.get("id", ""))
	if id == "" or id == my_id:
		return
	if data.get("gone", false):
		if _entries.erase(id):
			lobby_changed.emit()
		return
	var known: Dictionary = _entries.get(id, {})
	var entry := {"id": id, "name": _clean_name(str(data.get("name", ""))), "level": int(data.get("level", 1)), "count": int(data.get("count", 1)), "seen": Time.get_ticks_msec()}
	_entries[id] = entry
	if known.is_empty() or known["count"] != entry["count"]:
		lobby_changed.emit()

func _expire_entries(now: int) -> void:
	var stale := _entries.keys().filter(func(id: String) -> bool: return now - _entries[id]["seen"] > ENTRY_TTL_MSEC)
	for id in stale:
		_entries.erase(id)
	if not stale.is_empty():
		lobby_changed.emit()

func _on_game_topic_message(data: Dictionary) -> void:
	var from: String = str(data.get("f", ""))
	match str(data.get("t", "")):
		"join":
			_on_join(from, data)
		"leave":
			_on_leave(from)
		"busy":
			if _mode == Mode.JOINING and data.get("to") == my_id:
				_to_browsing("That room is full or already playing")
		"room":
			_on_room(from, data)
		"closed":
			if (_mode == Mode.JOINING or _mode == Mode.ROOM) and from == _host_id:
				_to_browsing("The host closed the room")
		"start":
			_on_start(from, data)
		_:
			if _mode == Mode.PLAYING and _seat_of(from) >= 0:
				_on_player_message(data, from)

func _on_join(from: String, data: Dictionary) -> void:
	if from == "" or _host_id != my_id:
		return
	if _mode == Mode.HOSTING and _seat_of(from) >= 0:
		_broadcast_room()
	elif _mode == Mode.HOSTING and _players.size() < MAX_PLAYERS:
		_players.append({"id": from, "name": _clean_name(str(data.get("name", "")))})
		_room_updated()
	elif _mode == Mode.HOSTING or _mode == Mode.PLAYING:
		_publish(_game_topic(my_id), {"f": my_id, "t": "busy", "to": from})

func _on_leave(from: String) -> void:
	var seat := _seat_of(from)
	if _mode != Mode.HOSTING or seat <= 0:
		return
	_players.remove_at(seat)
	_room_updated()

func _on_room(from: String, data: Dictionary) -> void:
	if from != _host_id or (_mode != Mode.JOINING and _mode != Mode.ROOM):
		return
	var players := _parse_players(data.get("players"))
	if _index_of(players, my_id) < 0:
		return
	_players = players
	_level = int(data.get("level", 1))
	_last_room_msec = Time.get_ticks_msec()
	if _mode == Mode.JOINING:
		_mode = Mode.ROOM
		_join_deadline_msec = 0
		status_changed.emit("")
	room_changed.emit()

func _on_start(from: String, data: Dictionary) -> void:
	if (_mode != Mode.ROOM and _mode != Mode.JOINING) or from != _host_id:
		return
	var players := _parse_players(data.get("players"))
	var seat := _index_of(players, my_id)
	if seat < 0 or players.size() < MIN_PLAYERS:
		_to_browsing("That room started without you")
		return
	_players = players
	_begin_match(seat, int(data.get("seed", 1)), int(data.get("level", 1)))

func _on_player_message(data: Dictionary, from: String) -> void:
	if not _last_rx.has(from):
		return
	_last_rx[from] = Time.get_ticks_msec()
	var type := str(data.get("t", ""))
	if type == "ping":
		return
	if type == "ack":
		if data.get("to") == my_id:
			_acked[from] = maxi(_acked.get(from, 0), int(data.get("n", 0)))
		return
	var number := int(data.get("n", 0))
	if number == _rx_seq.get(from, 0) + 1:
		_rx_seq[from] = number
		data["s"] = _seat_of(from)
		_deliver(data)
		if type == "bye":
			_last_rx.erase(from)
	if number > 0:
		_send_raw({"t": "ack", "to": from, "n": _rx_seq.get(from, 0)})

func _resend_unconfirmed() -> void:
	var confirmed := _tx_seq
	for id: String in _last_rx:
		confirmed = mini(confirmed, _acked.get(id, 0))
	while not _sent.is_empty() and _sent[0]["n"] <= confirmed:
		_sent.pop_front()
	for message in _sent:
		_send_raw(message)

func _begin_match(seat: int, seed_value: int, level: int) -> void:
	_mode = Mode.PLAYING
	_join_deadline_msec = 0
	var now := Time.get_ticks_msec()
	_last_rx.clear()
	var names: Array[String] = []
	for player in _players:
		names.append(player["name"])
		if player["id"] != my_id:
			_last_rx[player["id"]] = now
	_next_ping_msec = now + PING_MSEC
	_tx_seq = 0
	_sent.clear()
	_acked.clear()
	_rx_seq.clear()
	_entries.clear()
	_inbox.clear()
	_listening = false
	var config := RunConfig.new(ModeCatalog.find(OnlineDefinition.ID), {
		&"seat": seat,
		&"seed": seed_value,
		&"level": level,
		&"names": names,
	})
	match_ready.emit(config)

func _deliver(message: Dictionary) -> void:
	if _listening:
		game_message.emit(message)
	else:
		_inbox.append(message)

## The player's character leaves the game at its next turn (see RemoteController); the others play on.
func _player_gone(id: String) -> void:
	if _last_rx.erase(id):
		_deliver({"t": "bye", "s": _seat_of(id)})

## Everybody silent at once means our own link is down, not that all of them left.
func _drop_silent_players(now: int) -> void:
	var silent: Array[String] = []
	for id: String in _last_rx:
		if now - _last_rx[id] > SILENCE_MSEC:
			silent.append(id)
	if silent.is_empty():
		return
	if silent.size() == _last_rx.size():
		_lose_connection("Lost contact with the other players")
		return
	for id in silent:
		_player_gone(id)

func _lose_connection(reason: String) -> void:
	if _mode != Mode.PLAYING:
		return
	_mode = Mode.IDLE
	connection_lost.emit(reason)

func _close_room() -> void:
	_publish_lobby({"id": my_id, "gone": true})
	_publish(_game_topic(my_id), {"f": my_id, "t": "closed"})
	_host_id = ""
	_to_browsing("")

func _to_browsing(status: String) -> void:
	_host_id = ""
	_players.clear()
	_set_mode(Mode.BROWSING)
	if status != "":
		status_changed.emit(status)
	room_changed.emit()

## The host's room changed: tell the guests and the lobby.
func _room_updated() -> void:
	_broadcast_room()
	_publish_entry()
	room_changed.emit()

func _broadcast_room() -> void:
	_publish(_game_topic(my_id), {"f": my_id, "t": "room", "level": _level, "players": _players})

func _seat_of(id: String) -> int:
	return _index_of(_players, id)

static func _index_of(players: Array[Dictionary], id: String) -> int:
	for seat in players.size():
		if players[seat]["id"] == id:
			return seat
	return -1

func _name_of(id: String) -> String:
	var seat := _seat_of(id)
	return _players[seat]["name"] if seat >= 0 else "A player"

## Messages come from the network: keep only well-formed entries, at most a full room's worth.
func _parse_players(raw: Variant) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	if not (raw is Array):
		return players
	for item: Variant in raw:
		if players.size() >= MAX_PLAYERS:
			break
		if item is Dictionary and str(item.get("id", "")) != "":
			players.append({"id": str(item["id"]), "name": _clean_name(str(item.get("name", "")))})
	return players

func _publish_entry() -> void:
	_publish_lobby({"id": my_id, "name": _name, "level": _level, "count": _players.size()})

func _publish_lobby(message: Dictionary) -> void:
	_publish(LOBBY_TOPIC, message)

func _publish(topic: String, message: Dictionary) -> void:
	if _client != null:
		_client.publish(topic, JSON.stringify(message).to_utf8_buffer())

static func _game_topic(host_id: String) -> String:
	return ROOT + "game/" + host_id

static func _clean_name(text: String) -> String:
	var cleaned := text.strip_edges().left(MAX_NAME_LENGTH)
	return cleaned if cleaned != "" else ProfileData.DEFAULT_PLAYER_NAME
