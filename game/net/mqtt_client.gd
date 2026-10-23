## Minimal MQTT 3.1.1 client over WebSocket, QoS 0 only: just enough to use a public
## broker as the meeting point and message relay of an online match. Works on every
## platform (WebSocketPeer is built in, including web). Call poll() every frame.
class_name MqttClient
extends RefCounted

## `was_connected` = the MQTT handshake had finished (false = could not reach the broker).
signal disconnected(was_connected: bool)
signal connected
signal message_received(topic: String, payload: PackedByteArray)

const KEEPALIVE_SECONDS := 60
const PING_INTERVAL_MSEC := 25000
const CONNECT_TIMEOUT_MSEC := 8000
## After close() the socket stays open this long so the last publishes still get out.
const CLOSE_GRACE_MSEC := 400

const _CONNECT := 0x10
const _CONNACK := 2
const _PUBLISH := 3
const _SUBSCRIBE := 0x82
const _PINGREQ := 0xC0
const _DISCONNECT := 0xE0

var _socket: WebSocketPeer
var _buffer := PackedByteArray()
var _started_msec := 0
var _last_ping_msec := 0
var _socket_open := false
var _ready := false
var _close_at_msec := 0
var _packet_id := 0
var _client_id := ""

func open(url: String, client_id: String) -> void:
	_client_id = client_id
	_socket = WebSocketPeer.new()
	_socket.supported_protocols = PackedStringArray(["mqtt"])
	_started_msec = Time.get_ticks_msec()
	if _socket.connect_to_url(url) != OK:
		_socket = null

## False once the client is closed, closing or failed: it is done and only worth dropping.
func is_alive() -> bool:
	return _socket != null

func is_ready() -> bool:
	return _ready and _close_at_msec == 0

func publish(topic: String, payload: PackedByteArray) -> void:
	if not is_ready():
		return
	var body := _utf8(topic)
	body.append_array(payload)
	_send_packet(_PUBLISH << 4, body)

func subscribe(topic_filter: String) -> void:
	if not is_ready():
		return
	_packet_id = _packet_id % 65535 + 1
	var body := PackedByteArray([_packet_id >> 8, _packet_id & 0xFF])
	body.append_array(_utf8(topic_filter))
	body.append(0)
	_send_packet(_SUBSCRIBE, body)

## Says goodbye and lets the socket drain; keep calling poll() until is_alive() turns false.
func close() -> void:
	if _socket == null or _close_at_msec != 0:
		return
	if _ready:
		_send_packet(_DISCONNECT, PackedByteArray())
	_ready = false
	_close_at_msec = Time.get_ticks_msec() + CLOSE_GRACE_MSEC

func poll() -> void:
	if _socket == null:
		return
	_socket.poll()
	var now := Time.get_ticks_msec()
	if _close_at_msec != 0:
		if now >= _close_at_msec or _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_socket.close()
			_socket = null
		return
	match _socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _started_msec > CONNECT_TIMEOUT_MSEC:
				_fail()
		WebSocketPeer.STATE_OPEN:
			if not _socket_open:
				_socket_open = true
				_send_connect()
			while _socket.get_available_packet_count() > 0:
				_buffer.append_array(_socket.get_packet())
			_parse()
			if _ready and now - _last_ping_msec > PING_INTERVAL_MSEC:
				_last_ping_msec = now
				_send_packet(_PINGREQ, PackedByteArray())
		WebSocketPeer.STATE_CLOSED:
			_fail()

func _fail() -> void:
	var was_connected := _ready
	if _socket != null:
		_socket.close()
	_socket = null
	_ready = false
	disconnected.emit(was_connected)

func _send_connect() -> void:
	var body := _utf8("MQTT")
	# Level 4 = 3.1.1; flags: clean session; keepalive.
	body.append_array(PackedByteArray([4, 0x02, KEEPALIVE_SECONDS >> 8, KEEPALIVE_SECONDS & 0xFF]))
	body.append_array(_utf8(_client_id))
	_send_packet(_CONNECT, body)

func _send_packet(header: int, body: PackedByteArray) -> void:
	var packet := PackedByteArray([header])
	var length := body.size()
	while true:
		var digit := length % 128
		length /= 128
		packet.append(digit | (0x80 if length > 0 else 0))
		if length == 0:
			break
	packet.append_array(body)
	_socket.send(packet, WebSocketPeer.WRITE_MODE_BINARY)

static func _utf8(text: String) -> PackedByteArray:
	var bytes := text.to_utf8_buffer()
	var result := PackedByteArray([bytes.size() >> 8, bytes.size() & 0xFF])
	result.append_array(bytes)
	return result

## One WebSocket message may carry several MQTT packets or only part of one.
func _parse() -> void:
	while _buffer.size() >= 2:
		var length := 0
		var multiplier := 1
		var index := 1
		var complete := false
		while index < _buffer.size() and index <= 4:
			var digit := _buffer[index]
			length += (digit & 0x7F) * multiplier
			multiplier *= 128
			index += 1
			if digit & 0x80 == 0:
				complete = true
				break
		if not complete or _buffer.size() < index + length:
			return
		var header := _buffer[0]
		var body := _buffer.slice(index, index + length)
		_buffer = _buffer.slice(index + length)
		_handle(header, body)
		if _socket == null:
			return

func _handle(header: int, body: PackedByteArray) -> void:
	match header >> 4:
		_CONNACK:
			if body.size() >= 2 and body[1] == 0:
				_ready = true
				_last_ping_msec = Time.get_ticks_msec()
				connected.emit()
			else:
				_fail()
		_PUBLISH:
			var topic_length := (body[0] << 8) | body[1]
			var topic := body.slice(2, 2 + topic_length).get_string_from_utf8()
			var offset := 2 + topic_length
			if (header >> 1) & 3 > 0:
				offset += 2
			message_received.emit(topic, body.slice(offset))
