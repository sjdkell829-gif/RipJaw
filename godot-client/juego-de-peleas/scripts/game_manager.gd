extends Node

var room_id: String  = ""
var ws_url: String   = ""
var opponent_id: int = 0

var player1 = null
var player2 = null

@onready var p1_damage: Label     = $HUD/P1Damage
@onready var p2_damage: Label     = $HUD/P2Damage
@onready var timer_label: Label   = $HUD/Timer
@onready var victory_label: Label = $HUD/VictoryLabel
@onready var p1_stocks: Label     = $HUD/P1Stocks
@onready var p2_stocks: Label     = $HUD/P2Stocks

var game_time: float   = 180.0
var time_left: float   = 180.0
var game_running: bool = false
var game_ended: bool   = false

var local_fighter
var remote_fighter


func _ready():
	if victory_label:
		victory_label.hide()

	room_id     = GameData.room_id
	ws_url      = GameData.ws_url
	opponent_id = GameData.opponent_id

	_spawn_players()

	if room_id == "":
		# ── Modo local ──────────────────────────────────────
		player1.setup(1, true)
		if GameData.vs_bot:
			player2.setup(2, false)
		else:
			player2.setup(2, true)
		local_fighter  = player1
		remote_fighter = player2
		game_running   = true
	else:
		# ── Modo online ─────────────────────────────────────
		var parts   = room_id.split("_")
		var room_p1 = int(parts[0]) if parts.size() >= 2 else 0

		if ApiClient.local_player_id == room_p1:
			# Soy P1
			player1.setup(ApiClient.local_player_id, true)
			player2.setup(opponent_id, false)
			local_fighter  = player1
			remote_fighter = player2
		else:
			# Soy P2
			player1.setup(opponent_id, false)
			player2.setup(ApiClient.local_player_id, true)
			local_fighter  = player2
			remote_fighter = player1

	player1.stocks = GameData.stocks
	player2.stocks = GameData.stocks
	_update_stocks_display()

	player1.took_damage.connect(_on_damage_updated)
	player1.died.connect(_on_player_died)
	player2.took_damage.connect(_on_damage_updated)
	player2.died.connect(_on_player_died)

	# Conectar WebSocket si hay sala online
	var ws = get_node_or_null("/root/WebSocketClient")
	if ws and ws_url != "":
		ws.game_started.connect(_on_game_started)
		ws.game_state_received.connect(_on_game_state)
		ws.game_over.connect(_on_game_over)
		await ws.connect_to_room(ws_url, room_id)
		# Iniciar juego inmediatamente al conectar
		game_running = true
	

func _spawn_players():
	var p1_scene_path = GameData.p1_scene
	if p1_scene_path == "" or not ResourceLoader.exists(p1_scene_path):
		p1_scene_path = "res://scenes/player_deku.tscn"
	var p1_scene = load(p1_scene_path)
	player1 = p1_scene.instantiate()
	player1.position = Vector2(300, 150)
	add_child(player1)

	var p2_scene_path = GameData.p2_scene
	if GameData.vs_bot:
		p2_scene_path = "res://scenes/player_baki.tscn"
	if p2_scene_path == "" or not ResourceLoader.exists(p2_scene_path):
		p2_scene_path = "res://scenes/player_deku.tscn"
	var p2_scene = load(p2_scene_path)
	player2 = p2_scene.instantiate()
	player2.position = Vector2(900, 150)
	add_child(player2)

	player1.add_to_group("fighters")
	player2.add_to_group("fighters")


func _process(delta):
	if not game_running:
		return
	time_left -= delta
	if timer_label:
		timer_label.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	if time_left <= 0:
		_end_game()

	# Enviar input del jugador local al servidor
	var ws = get_node_or_null("/root/WebSocketClient")
	if ws and ws.is_connected_to_room and local_fighter:
		var dir = 0.0
		if local_fighter.is_local_player:
			dir = Input.get_axis(
				local_fighter._actions.get("left", "p1_left"),
				local_fighter._actions.get("right", "p1_right")
			)
		ws.send_input(
			dir,
			0.0,
			Input.is_action_pressed(local_fighter._actions.get("attack", "p1_attack")),
			Input.is_action_just_pressed(local_fighter._actions.get("jump", "p1_jump"))
		)


func _on_game_started():
	game_running = true


func _on_game_state(data: Dictionary):
	if remote_fighter:
		remote_fighter.apply_remote_state(data)


func _on_game_over(_winner: String):
	_end_game()


func _on_damage_updated(pid: int, percent: float):
	if pid == player1.player_id:
		if p1_damage:
			p1_damage.text = "P1: %.0f%%" % percent
	else:
		if p2_damage:
			p2_damage.text = "P2: %.0f%%" % percent
	_update_stocks_display()


func _on_player_died(_pid: int):
	_update_stocks_display()
	await get_tree().process_frame
	await get_tree().process_frame
	if player1.stocks <= 0 or player2.stocks <= 0:
		await get_tree().create_timer(1.0).timeout
		_end_game()


func _update_stocks_display():
	if p1_stocks:
		p1_stocks.text = "❤️".repeat(max(0, player1.stocks))
	if p2_stocks:
		p2_stocks.text = "❤️".repeat(max(0, player2.stocks))


func _end_game():
	if game_ended:
		return
	game_ended   = true
	game_running = false

	var local_won: bool = false
	if local_fighter != null and remote_fighter != null:
		if local_fighter.stocks > remote_fighter.stocks:
			local_won = true
		elif local_fighter.stocks == remote_fighter.stocks:
			local_won = local_fighter.damage_percent <= remote_fighter.damage_percent

	if victory_label:
		victory_label.text = "¡VICTORIA!" if local_won else "¡DERROTA!"
		victory_label.show()

	_report_and_exit(local_won)


func _report_and_exit(local_won: bool):
	var winner_id = ApiClient.local_player_id if local_won else opponent_id
	var loser_id  = opponent_id if local_won else ApiClient.local_player_id

	if room_id != "":
		ApiClient.report_result(room_id, winner_id, loser_id)
		await ApiClient.result_saved
		# Limpiar room para que no se reutilice en la próxima búsqueda
		ApiClient.cleanup_room(room_id)

	await get_tree().create_timer(3.0).timeout

	var ws = get_node_or_null("/root/WebSocketClient")
	if ws:
		ws.disconnect_from_room()

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
