# ============================================================
#   SmashAPI — game_manager.gd
#   Adjuntar al nodo raíz de la escena de juego
# ============================================================
extends Node

var room_id: String  = ""
var ws_url: String   = ""
var opponent_id: int = 0

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var p1_damage: Label = $HUD/P1Damage
@onready var p2_damage: Label = $HUD/P2Damage
@onready var timer_label: Label = $HUD/Timer

var game_time: float   = 180.0
var time_left: float   = 180.0
var game_running: bool = false


func _ready():
	room_id     = GameData.room_id
	ws_url      = GameData.ws_url
	opponent_id = GameData.opponent_id

	# Player 1: siempre local, usa player_id 1 si no hay sesión iniciada
	player1.player_id       = ApiClient.local_player_id if ApiClient.local_player_id != 0 else 1
	player1.is_local_player = true

	# Player 2: local en modo offline, remoto en modo online
	player2.player_id       = opponent_id if opponent_id != 0 else 2
	player2.is_local_player = (room_id == "")  # ← clave: P2 se controla local si no hay sala online

	player1.took_damage.connect(_on_damage_updated)
	player1.died.connect(_on_player_died)
	player2.took_damage.connect(_on_damage_updated)
	player2.died.connect(_on_player_died)

	# Conectar WebSocket solo si hay sala online
	var ws = get_node_or_null("/root/WebSocketClient")
	if ws and ws_url != "":
		ws.game_started.connect(_on_game_started)
		ws.game_state_received.connect(_on_game_state)
		ws.game_over.connect(_on_game_over)
		await ws.connect_to_room(ws_url, room_id)
	else:
		# Modo local: ambos jugadores activos desde el inicio
		game_running = true


func _process(delta):
	if not game_running:
		return
	time_left -= delta
	if timer_label:
		timer_label.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	if time_left <= 0:
		_end_game()


func _on_game_started():
	game_running = true


func _on_game_state(data: Dictionary):
	# En online, Player2 recibe estado remoto (no es local)
	player2.apply_remote_state(data)


func _on_game_over(winner: String):
	game_running = false
	var local_won = winner == str(ApiClient.local_player_id)
	_report_and_exit(local_won)


func _on_damage_updated(pid: int, percent: float):
	if pid == player1.player_id:
		if p1_damage:
			p1_damage.text = "P1: %.0f%%" % percent
	else:
		if p2_damage:
			p2_damage.text = "P2: %.0f%%" % percent


func _on_player_died(pid: int):
	if (pid == player1.player_id and player1.stocks <= 0) or \
	   (pid == player2.player_id and player2.stocks <= 0):
		_end_game()


func _end_game():
	if not game_running:
		return
	game_running = false
	var local_won = player1.stocks > player2.stocks or \
		(player1.stocks == player2.stocks and player1.damage_percent < player2.damage_percent)
	_report_and_exit(local_won)


func _report_and_exit(local_won: bool):
	var winner_id = ApiClient.local_player_id if local_won else opponent_id
	var loser_id  = opponent_id if local_won else ApiClient.local_player_id

	if room_id != "":
		ApiClient.report_result(room_id, winner_id, loser_id)
		await ApiClient.result_saved

	await get_tree().create_timer(3.0).timeout

	var ws = get_node_or_null("/root/WebSocketClient")
	if ws:
		ws.disconnect_from_room()

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
