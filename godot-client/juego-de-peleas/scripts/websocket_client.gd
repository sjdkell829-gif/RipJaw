# ============================================================
#   SmashAPI — WebSocket_Client.gd
#   Sincronización en tiempo real con el servidor
# ============================================================
extends Node

signal connected()
signal disconnected()
signal game_started()
signal game_state_received(data)
signal game_over(winner_id)

var _socket := WebSocketPeer.new()
var _room_id: String = ""
var _connected: bool = false

var is_connected_to_room: bool:
	get: return _connected


func _process(_delta):
	var state = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_socket.poll()
		while _socket.get_available_packet_count() > 0:
			var raw  = _socket.get_packet()
			var text = raw.get_string_from_utf8()
			_handle_message(text)

	elif state == WebSocketPeer.STATE_CONNECTING:
		_socket.poll()

	elif _connected and state == WebSocketPeer.STATE_CLOSED:
		_connected = false
		disconnected.emit()


# ── Conexión ───────────────────────────────────────────────

func connect_to_room(ws_url: String, room_id: String):
	# Si ya está conectado o conectando, ignorar llamada duplicada
	var state = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
		print("[WS] Ya conectado/conectando, ignorando llamada duplicada")
		_connected = true
		return

	_room_id = room_id
	print("=== WS conectando a: ", ws_url)
	var err = _socket.connect_to_url(ws_url)
	if err != OK:
		push_error("[WS] No se pudo conectar: " + str(err))
		return

	await _wait_for_open()
	_connected = true
	connected.emit()
	game_started.emit()
	print("=== WS conectado OK al room: ", room_id)


func disconnect_from_room():
	_socket.close()
	_connected = false


# ── Enviar mensajes ────────────────────────────────────────

func send_input(x: float, y: float, attacking: bool, jumping: bool, pos: Vector2, vel: Vector2):
	if not _connected:
		return
	var msg = JSON.stringify({
		"type":      "input",
		"x":         x,
		"y":         y,
		"attacking": attacking,
		"jumping":   jumping,
		"px":        pos.x,
		"py":        pos.y,
		"vx":        vel.x,
		"vy":        vel.y
	})
	_socket.send_text(msg)


func send_hit(target_player_id: int, damage: int):
	if not _connected:
		return
	var msg = JSON.stringify({
		"type":   "player_hit",
		"target": str(target_player_id),
		"damage": damage
	})
	_socket.send_text(msg)


# ── Procesar mensajes entrantes ────────────────────────────

func _handle_message(text: String):
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return

	print("[WS] Mensaje recibido: ", data)

	match data.get("type", ""):
		"game_start":
			game_started.emit()
		"input", "game_state":
			game_state_received.emit(data)
		"player_hit":
			game_state_received.emit(data)
		"game_over":
			game_over.emit(data.get("winner", ""))
		_:
			# char_cursor, char_ready y cualquier otro tipo
			game_state_received.emit(data)


# ── Utilidad interna ───────────────────────────────────────

func _wait_for_open() -> void:
	while _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_socket.poll()
		await get_tree().process_frame
