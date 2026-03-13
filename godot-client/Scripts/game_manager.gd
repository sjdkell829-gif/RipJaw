# ============================================================
#   SmashAPI — game_manager.gd
#   Adjuntar a un nodo raíz de la escena de juego
#   Orquesta la partida online completa
# ============================================================

extends Node

# Datos de la partida (se llenan desde main_menu antes de cargar escena)
var room_id: String     = ""
var ws_url: String      = ""
var opponent_id: int    = 0

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var hud                      = $HUD
@onready var timer_label: Label       = $HUD/TimerLabel

var game_time: float  = 180.0
var time_left: float  = 180.0
var game_running: bool = false


func _ready():
	# Recibir datos pasados desde el menú
	room_id     = GameData.room_id
	ws_url      = GameData.ws_url
	opponent_id = GameData.opponent_id

	# Asignar IDs a los fighters
	player1.player_id      = ApiClient.local_player_id
	player1.is_local_player = true
	player2.player_id      = opponent_id
	player2.is_local_player = false

	# Conectar señales del fighter local
	player1.took_damage.connect(_on_damage_updated)
	player1.died.connect(_on_player_died)
	player2.took_damage.connect(_on_damage_updated)
	player2.died.connect(_on_player_died)

	# Conectar señales del WebSocket
	WebSocketClient.game_started.connect(_on_game_started)
	WebSocketClient.game_state_received.connect(_on_game_state)
	WebSocketClient.game_over.connect(_on_game_over)

	# Conectar al room
	await WebSocketClient.connect_to_room(ws_url, room_id)


func _process(delta):
	if not game_running:
		return

	time_left -= delta
	timer_label.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]

	if time_left <= 0:
		_end_game()


# ── Eventos WebSocket ──────────────────────────────────────

func _on_game_started():
	game_running = true
	hud.show_message("¡PELEA!")
	print("[Game] Partida iniciada")


func _on_game_state(data: Dictionary):
	# Aplicar estado al fighter remoto
	player2.apply_remote_state(data)


func _on_game_over(winner: String):
	game_running = false
	var local_won = winner == str(ApiClient.local_player_id)
	hud.show_game_over("¡GANASTE!" if local_won else "¡PERDISTE!")
	_report_and_exit(local_won)


# ── Señales de los fighters ────────────────────────────────

func _on_damage_updated(pid: int, percent: float):
	hud.update_damage(pid, percent)


func _on_player_died(pid: int):
	hud.update_stocks(pid, player1.stocks if pid == player1.player_id else player2.stocks)

	# Si se quedó sin vidas
	if (pid == player1.player_id and player1.stocks <= 0) or \
	   (pid == player2.player_id and player2.stocks <= 0):
		_end_game()


# ── Fin de partida ─────────────────────────────────────────

func _end_game():
	if not game_running:
		return
	game_running = false

	var local_won = player1.stocks > player2.stocks or \
		(player1.stocks == player2.stocks and player1.damage_percent < player2.damage_percent)

	hud.show_game_over("¡GANASTE!" if local_won else "¡PERDISTE!")
	_report_and_exit(local_won)


func _report_and_exit(local_won: bool):
	var winner_id = ApiClient.local_player_id if local_won else opponent_id
	var loser_id  = opponent_id if local_won else ApiClient.local_player_id

	ApiClient.report_result(room_id, winner_id, loser_id)
	await ApiClient.result_saved

	await get_tree().create_timer(3.0).timeout
	WebSocketClient.disconnect_from_room()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")