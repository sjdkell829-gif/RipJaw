# ============================================================
#   RipJaw — game_manager.gd
# ============================================================
extends Node

var player1 = null
var player2 = null

@onready var p1_damage:    Label = $HUD/P1Damage
@onready var p2_damage:    Label = $HUD/P2Damage
@onready var timer_label:  Label = $HUD/Timer
@onready var victory_label: Label = $HUD/VictoryLabel
@onready var p1_stocks:    Label = $HUD/P1Stocks
@onready var p2_stocks:    Label = $HUD/P2Stocks

var game_time:    float = 180.0
var time_left:    float = 180.0
var game_running: bool  = false
var game_ended:   bool  = false

var local_fighter  = null
var remote_fighter = null


func _ready():
	if victory_label:
		victory_label.hide()

	_spawn_players()

	if not GameData.is_online:
		player1.setup(1, true,  1)
		if GameData.vs_bot:
			player2.setup(2, false, 2)
		else:
			player2.setup(2, true,  2)
		local_fighter  = player1
		remote_fighter = player2
		game_running   = true
	else:
		if GameData.is_host:
			player1.setup(ApiClient.local_player_id, true,  1)
			player2.setup(GameData.opponent_id,      false, 2)
			local_fighter  = player1
			remote_fighter = player2
		else:
			player1.setup(GameData.opponent_id,      false, 1)
			player2.setup(ApiClient.local_player_id, true,  2)
			local_fighter  = player2
			remote_fighter = player1

	player1.stocks = GameData.stocks
	player2.stocks = GameData.stocks
	_update_stocks_display()

	player1.took_damage.connect(_on_damage_updated)
	player1.died.connect(_on_player_died)
	player2.took_damage.connect(_on_damage_updated)
	player2.died.connect(_on_player_died)

	if GameData.is_online:
		var ws = get_node_or_null("/root/WebSocketClient")
		if ws:
			ws.game_started.connect(_on_game_started)
			ws.game_state_received.connect(_on_game_state)
			ws.game_over.connect(_on_game_over)
			if not ws.is_connected_to_room:
				await ws.connect_to_room(GameData.ws_url, GameData.room_id)
			game_running = true



func _spawn_players():
	var p1_path = GameData.p1_scene
	if p1_path == "" or not ResourceLoader.exists(p1_path):
		p1_path = "res://scenes/player_deku.tscn"
	player1 = load(p1_path).instantiate()
	player1.position = Vector2(300, 150)
	add_child(player1)

	var p2_path = GameData.p2_scene
	if GameData.vs_bot:
		p2_path = "res://scenes/player_baki.tscn"
	if p2_path == "" or not ResourceLoader.exists(p2_path):
		p2_path = "res://scenes/player_deku.tscn"
	player2 = load(p2_path).instantiate()
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

	if GameData.is_online:
		var ws = get_node_or_null("/root/WebSocketClient")
		if ws and ws.is_connected_to_room and local_fighter:
			var actions = local_fighter._actions
			var dir = Input.get_axis(
				actions.get("left",  "p1_left"),
				actions.get("right", "p1_right")
			)
			ws.send_input(
				dir, 0.0,
				Input.is_action_pressed(actions.get("attack", "p1_attack")),
				Input.is_action_just_pressed(actions.get("jump", "p1_jump")),
				local_fighter.global_position,
				local_fighter.velocity
			)

func _on_game_started():
	game_running = true


func _on_game_state(data: Dictionary):
	var t = data.get("type", "")
	print("=== _on_game_state tipo: ", t)
	if t == "char_cursor" or t == "char_ready":
		return
	if remote_fighter:
		remote_fighter.apply_remote_state(data)
	else:
		print("=== remote_fighter es NULL")


func _on_game_over(_winner: String):
	_end_game()


func _on_damage_updated(pid: int, percent: float):
	if pid == player1.player_id:
		if p1_damage: p1_damage.text = "P1: %.0f%%" % percent
	else:
		if p2_damage: p2_damage.text = "P2: %.0f%%" % percent
	_update_stocks_display()


func _on_player_died(_pid: int):
	_update_stocks_display()
	await get_tree().process_frame
	await get_tree().process_frame
	if player1.stocks <= 0 or player2.stocks <= 0:
		await get_tree().create_timer(1.0).timeout
		_end_game()


func _update_stocks_display():
	if p1_stocks: p1_stocks.text = "❤️".repeat(max(0, player1.stocks))
	if p2_stocks: p2_stocks.text = "❤️".repeat(max(0, player2.stocks))


func _end_game():
	if game_ended:
		return
	game_ended   = true
	game_running = false

	var local_won: bool = false
	if local_fighter and remote_fighter:
		if local_fighter.stocks > remote_fighter.stocks:
			local_won = true
		elif local_fighter.stocks == remote_fighter.stocks:
			local_won = local_fighter.damage_percent <= remote_fighter.damage_percent

	if victory_label:
		victory_label.text = "¡VICTORIA!" if local_won else "¡DERROTA!"
		victory_label.show()

	_report_and_exit(local_won)


func _report_and_exit(local_won: bool):
	var winner_id = ApiClient.local_player_id if local_won else GameData.opponent_id
	var loser_id  = GameData.opponent_id if local_won else ApiClient.local_player_id

	if GameData.is_online and GameData.room_id != "":
		ApiClient.report_result(GameData.room_id, winner_id, loser_id)
		await ApiClient.result_saved
		ApiClient.cleanup_room(GameData.room_id)
		# Limpiar estado online para la próxima partida
		GameData.room_id   = ""
		GameData.ws_url    = ""
		GameData.is_online = false
		GameData.is_host   = false

	await get_tree().create_timer(3.0).timeout

	var ws = get_node_or_null("/root/WebSocketClient")
	if ws:
		ws.disconnect_from_room()

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
