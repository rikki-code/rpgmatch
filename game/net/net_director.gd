## Online matchmaking and the wire to the opponent, autoloaded as `Net`.
##
## There is no game server: both players connect to a public MQTT broker (MqttClient) that
## only relays small JSON messages. Hosts announce themselves on a lobby topic, a guest joins
## through the host's game topic, and from then on the two clients run the same deterministic
## game and only exchange moves (see OnlineSync). Nothing is stored on the broker.
class_name NetDirector
extends Node

signal status_changed(text: String)
signal lobby_changed
## The match is agreed: start the game scene with this config.
signal match_ready(config: RunConfig)
## A message of the opponent for the running game (see attach_game).
signal game_message(message: Dictionary)
signal opponent_left(reason: String)

enum Mode { IDLE, BROWSING, HOSTING, JOINING, PLAYING }

const BROKER_URLS: Array[String] = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
]
## Topics are public: anyone on the broker can read them, so a distinctive prefix keeps other users out of ours.
const ROOT := "rpgmatch-pvp/v1/"
const LOBBY_TOPIC := ROOT + "lobby"
const WHO_TOPIC := ROOT + "who"
const MAX_NAME_LENGTH := 16
const ENTRY_TTL_MSEC := 10000
const HOST_BEAT_MSEC := 4000
const JOIN_TIMEOUT_MSEC := 8000
const PING_MSEC := 3000
const SILENCE_MSEC := 25000

var my_id := ""
var _mode := Mode.IDLE
var _client: MqttClient
var _retired: Array[MqttClient] = []
var _url_index := 0
var _subscribed := {}  # topic -> true, for the current connection
var _entries := {}  # host id -> {"id", "name", "level", "seen"}
var _name := ""
var _level := 1
var _host_id := ""
var _guest_id := ""
var _guest_name := ""
var _next_beat_msec := 0
var _join_deadline_msec := 0
var _next_ping_msec := 0
var _last_rx_msec := 0
var _listening := false
var _inbox: Array[Dictionary] = []

func _ready() -> void:
	# The pause menu must not freeze the connection.
	process_mode = Node.PROCESS_MODE_ALWAYS
	my_id = "%08x%08x" % [randi(), randi()]

## Hosts waiting for an opponent, as {"id", "name", "level"}.
func lobby() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries.values():
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return result

func is_hosting() -> bool:
	return _mode == Mode.HOSTING

func browse() -> void:
	_set_mode(Mode.BROWSING)

func host(player_name: String, level: int) -> void:
	_name = _clean_name(player_name)
	_level = level
	_guest_id = ""
	_set_mode(Mode.HOSTING)

func cancel_host() -> void:
	if _mode == Mode.HOSTING:
		_publish_lobby({"id": my_id, "gone": true})
		_set_mode(Mode.BROWSING)

func join(host_id: String, player_name: String) -> void:
	_name = _clean_name(player_name)
	_host_id = host_id
	_set_mode(Mode.JOINING)

## Drops out of lobby or match and closes the connection.
func leave() -> void:
	match _mode:
		Mode.HOSTING:
			_publish_lobby({"id": my_id, "gone": true})
		Mode.PLAYING:
			send_game({"t": "bye"})
	if _client != null:
		_client.close()
		_retired.append(_client)
		_client = null
	_subscribed.clear()
	_entries.clear()
	_inbox.clear()
	_listening = false
	_host_id = ""
	_guest_id = ""
	_mode = Mode.IDLE

## The running game starts listening: returns what the opponent sent while the scene loaded.
func attach_game() -> Array[Dictionary]:
	_listening = true
	var pending := _inbox.duplicate()
	_inbox.clear()
	return pending

func send_game(message: Dictionary) -> void:
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
		Mode.JOINING:
			if _join_deadline_msec != 0 and now >= _join_deadline_msec:
				_join_deadline_msec = 0
				_set_mode(Mode.BROWSING)
				status_changed.emit("No answer from the host")
		Mode.PLAYING:
			if now >= _next_ping_msec:
				_next_ping_msec = now + PING_MSEC
				send_game({"t": "ping"})
			if now - _last_rx_msec > SILENCE_MSEC:
				_lose_opponent("Opponent disconnected")

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
			_lose_opponent("Connection lost")
		else:
			_mode = Mode.IDLE
			status_changed.emit("Connection lost")
		return
	_url_index += 1
	if _url_index < BROKER_URLS.size():
		_connect()
		return
	_mode = Mode.IDLE
	status_changed.emit("Can't reach the server. Check your internet connection")

## Runs once the connection is up and again on every mode change.
func _enter_mode() -> void:
	_subscribe(LOBBY_TOPIC)
	match _mode:
		Mode.BROWSING:
			status_changed.emit("")
			_publish(WHO_TOPIC, {"id": my_id})
		Mode.HOSTING:
			_subscribe(WHO_TOPIC)
			_subscribe(_game_topic(my_id))
			_host_id = my_id
			_next_beat_msec = Time.get_ticks_msec() + HOST_BEAT_MSEC
			_publish_entry()
			status_changed.emit("Waiting for an opponent...")
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
	elif data.get("f", "") != my_id:
		_on_game_topic_message(data)

func _on_lobby_message(data: Dictionary) -> void:
	var id: String = str(data.get("id", ""))
	if id == "" or id == my_id:
		return
	if data.get("gone", false):
		if _entries.erase(id):
			lobby_changed.emit()
		return
	var known := _entries.has(id)
	_entries[id] = {"id": id, "name": _clean_name(str(data.get("name", ""))), "level": int(data.get("level", 1)), "seen": Time.get_ticks_msec()}
	if not known:
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
			if _mode != Mode.HOSTING:
				return
			if _guest_id != "":
				_publish(_game_topic(my_id), {"f": my_id, "t": "busy", "to": from})
				return
			_start_hosted_match(from, _clean_name(str(data.get("name", ""))))
		"busy":
			if _mode == Mode.JOINING and data.get("to") == my_id:
				_set_mode(Mode.BROWSING)
				status_changed.emit("That player is already in a match")
		"start":
			if _mode != Mode.JOINING or from != _host_id:
				return
			if data.get("to") != my_id:
				_set_mode(Mode.BROWSING)
				status_changed.emit("That player is already in a match")
				return
			_begin_match(1, int(data["seed"]), int(data["level"]), str(data["host_name"]), _name)
		_:
			if _mode == Mode.PLAYING and from == _opponent_id():
				_last_rx_msec = Time.get_ticks_msec()
				_on_opponent_message(data)

func _on_opponent_message(data: Dictionary) -> void:
	match str(data.get("t", "")):
		"ping":
			pass
		"bye":
			_lose_opponent("Opponent left the game")
		_:
			if _listening:
				game_message.emit(data)
			else:
				_inbox.append(data)

func _start_hosted_match(guest_id: String, guest_name: String) -> void:
	_guest_id = guest_id
	var seed_value := randi_range(1, 2000000000)
	_publish(_game_topic(my_id), {"f": my_id, "t": "start", "to": guest_id, "seed": seed_value, "level": _level, "host_name": _name})
	_publish_lobby({"id": my_id, "gone": true})
	_begin_match(0, seed_value, _level, _name, guest_name)

func _begin_match(role: int, seed_value: int, level: int, host_name: String, guest_name: String) -> void:
	_mode = Mode.PLAYING
	_join_deadline_msec = 0
	_last_rx_msec = Time.get_ticks_msec()
	_next_ping_msec = _last_rx_msec + PING_MSEC
	_entries.clear()
	_inbox.clear()
	_listening = false
	var config := RunConfig.new(ModeCatalog.find(OnlineDefinition.ID), {
		&"role": role,
		&"seed": seed_value,
		&"level": level,
		&"host_name": host_name,
		&"guest_name": guest_name,
	})
	match_ready.emit(config)

func _lose_opponent(reason: String) -> void:
	if _mode != Mode.PLAYING:
		return
	_mode = Mode.IDLE
	opponent_left.emit(reason)

func _opponent_id() -> String:
	return _guest_id if _host_id == my_id else _host_id

func _publish_entry() -> void:
	_publish_lobby({"id": my_id, "name": _name, "level": _level})

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
