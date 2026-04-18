# ============================================================
#   RipJaw — character_select.gd
# ============================================================
extends Control

var characters:       Array = []
var character_scenes: Array = [
	"res://scenes/player_deku.tscn",
	"res://scenes/player_baki.tscn",
	"res://scenes/player_richtofen.tscn",
]

var p1_cursor: int  = 0
var p2_cursor: int  = 1
var p1_ready:  bool = false
var p2_ready:  bool = false

var char_cards:      Array = []
var p1_indicator:    Label
var p2_indicator:    Label
var p1_status:       Label
var p2_status:       Label
var countdown_label: Label
var _countdown:      float = -1.0

var _is_online: bool = false


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("===CHARACTER SELECT===")
	print("is_online:", GameData.is_online)
	print("room:", GameData.room_id)
	
	
	for res in ["res://assets/stats_deku.tres",
				"res://assets/stats_baki.tres",
				"res://assets/stats_richtofen.tres"]:
		var s = load(res)
		if s:
			characters.append(s)
		else:
			push_error("No se encontró: " + res)

	if characters.size() > 0:
		p1_cursor = 0
		p2_cursor = min(1, characters.size() - 1)

	_is_online = GameData.is_online and ApiClient.local_player_id != 0

	if not _is_online and GameData.is_online:
		push_error("Intento de partida online sin sesión activa")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	_build_ui()
	_update_cursors()

	if _is_online:
		set_process(false)
		call_deferred("_connect_ws")


func _connect_ws():
	var ws = get_node_or_null("/root/WebSocketClient")
	if not ws:
		push_error("=== WebSocketClient no encontrado")
		set_process(true)
		return

	ws.game_state_received.connect(_on_ws_message)

	if ws.is_connected_to_room:
		print("=== WS ya estaba conectado")
		set_process(true)
		return

	print("=== WS conectando a: ", GameData.ws_url)
	await ws.connect_to_room(GameData.ws_url, GameData.room_id)
	print("=== WS conectado, is_connected: ", ws.is_connected_to_room)

	set_process(true)


# ── UI ─────────────────────────────────────────────────────

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "SELECCIONA TU PERSONAJE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 20
	title.offset_bottom = 60
	add_child(title)

	var grid = HBoxContainer.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grid.position = Vector2(-300, -80)
	grid.custom_minimum_size = Vector2(600, 200)
	grid.add_theme_constant_override("separation", 40)
	add_child(grid)

	for i in characters.size():
		var card = _make_card(i)
		grid.add_child(card)
		char_cards.append(card)

	var p1_panel = _make_player_panel(1)
	p1_panel.position = Vector2(50, 350)
	add_child(p1_panel)

	var p2_panel = _make_player_panel(2)
	p2_panel.position = Vector2(750, 350)
	add_child(p2_panel)

	var hint = Label.new()
	if _is_online:
		hint.text = "A/D mover   F confirmar   W cancelar"
	else:
		hint.text = "P1: A/D mover  F confirmar  W cancelar  |  P2: ←/→ mover  Enter confirmar  ↑ cancelar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -10
	hint.offset_top    = -40
	add_child(hint)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 48)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.position = Vector2(-60, -30)
	countdown_label.hide()
	add_child(countdown_label)


func _make_card(index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 200)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(200, 150)
	portrait_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if index < characters.size() and characters[index].portrait:
		portrait_rect.texture = characters[index].portrait
	vbox.add_child(portrait_rect)

	var name_label = Label.new()
	name_label.text = characters[index].character_name if index < characters.size() else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	return panel


func _make_player_panel(player_num: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 120)
	vbox.add_theme_constant_override("separation", 8)

	var title_lbl = Label.new()
	if _is_online:
		title_lbl.text = "TÚ" if player_num == 1 else "OPONENTE"
	else:
		title_lbl.text = "JUGADOR %d" % player_num
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_lbl)

	var char_label = Label.new()
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(char_label)

	var status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status)

	if player_num == 1:
		p1_indicator = char_label
		p1_status    = status
	else:
		p2_indicator = char_label
		p2_status    = status

	return vbox


# ── Input ──────────────────────────────────────────────────

func _process(delta):
	if characters.size() == 0:
		return
	_handle_input()
	if _countdown > 0:
		_countdown -= delta
		countdown_label.text = "¡PELEA EN %d!" % (int(_countdown) + 1)
		if _countdown <= 0:
			_start_game()


func _handle_input():
	# ── P1 siempre local ───────────────────────────────────
	if not p1_ready:
		if Input.is_action_just_pressed("p1_left"):
			p1_cursor = (p1_cursor - 1 + characters.size()) % characters.size()
			_update_cursors()
			_broadcast_cursor()
		if Input.is_action_just_pressed("p1_right"):
			p1_cursor = (p1_cursor + 1) % characters.size()
			_update_cursors()
			_broadcast_cursor()
		if Input.is_action_just_pressed("p1_attack"):
			p1_ready = true
			_update_cursors()
			_broadcast_ready()
			_check_both_ready()
	else:
		if Input.is_action_just_pressed("p1_jump"):
			p1_ready   = false
			_countdown = -1.0
			countdown_label.hide()
			_update_cursors()
			_broadcast_cursor()

	# ── P2 solo en modo local ──────────────────────────────
	if _is_online:
		return

	if not p2_ready:
		if Input.is_action_just_pressed("p2_left"):
			p2_cursor = (p2_cursor - 1 + characters.size()) % characters.size()
			_update_cursors()
		if Input.is_action_just_pressed("p2_right"):
			p2_cursor = (p2_cursor + 1) % characters.size()
			_update_cursors()
		if Input.is_action_just_pressed("p2_attack"):
			p2_ready = true
			_update_cursors()
			_check_both_ready()
	else:
		if Input.is_action_just_pressed("p2_jump"):
			p2_ready   = false
			_countdown = -1.0
			countdown_label.hide()
			_update_cursors()


# ── WebSocket ──────────────────────────────────────────────

func _broadcast_cursor():
	if not _is_online:
		return
	var ws = get_node_or_null("/root/WebSocketClient")
	if ws and ws.is_connected_to_room:
		print("=== ENVIANDO cursor: ", p1_cursor)
		ws._socket.send_text(JSON.stringify({
			"type":       "char_cursor",
			"char_index": p1_cursor
		}))
	else:
		print("=== WS NO CONECTADO al intentar enviar cursor")


func _broadcast_ready():
	if not _is_online:
		return
	var ws = get_node_or_null("/root/WebSocketClient")
	if ws and ws.is_connected_to_room:
		print("=== ENVIANDO ready: ", p1_cursor)
		ws._socket.send_text(JSON.stringify({
			"type":       "char_ready",
			"char_index": p1_cursor
		}))
	else:
		print("=== WS NO CONECTADO al intentar enviar ready")


func _on_ws_message(data: Dictionary):
	print("=== MENSAJE WS RECIBIDO: ", data)
	match data.get("type", ""):
		"char_cursor":
			var idx   = int(data.get("char_index", 0))
			p2_cursor = clamp(idx, 0, characters.size() - 1)
			_update_cursors()
		"char_ready":
			var idx   = int(data.get("char_index", 0))
			p2_cursor = clamp(idx, 0, characters.size() - 1)
			p2_ready  = true
			GameData.opponent_char_index = p2_cursor
			_update_cursors()
			_check_both_ready()


# ── Display ────────────────────────────────────────────────

func _update_cursors():
	for i in char_cards.size():
		var card  = char_cards[i]
		var style = StyleBoxFlat.new()
		style.border_width_left   = 3
		style.border_width_right  = 3
		style.border_width_top    = 3
		style.border_width_bottom = 3

		if i == p1_cursor and i == p2_cursor:
			style.border_color = Color.YELLOW
		elif i == p1_cursor:
			style.border_color = Color(0.2, 0.5, 1.0)
		elif i == p2_cursor:
			style.border_color = Color(1.0, 0.3, 0.3)
		else:
			style.border_color = Color(0.3, 0.3, 0.3)

		card.add_theme_stylebox_override("panel", style)

	if p1_indicator and p1_cursor < characters.size():
		p1_indicator.text = characters[p1_cursor].character_name
	if p2_indicator and p2_cursor < characters.size():
		p2_indicator.text = characters[p2_cursor].character_name

	if p1_status:
		p1_status.text = "✅ LISTO" if p1_ready else "Presiona F para confirmar"
		p1_status.add_theme_color_override("font_color", Color.GREEN if p1_ready else Color.WHITE)

	if p2_status:
		if _is_online:
			if p2_ready:
				p2_status.text = "✅ LISTO"
				p2_status.add_theme_color_override("font_color", Color.GREEN)
			else:
				p2_status.text = "Esperando oponente..."
				p2_status.add_theme_color_override("font_color", Color.WHITE)
		else:
			p2_status.text = "✅ LISTO" if p2_ready else "Presiona Enter para confirmar"
			p2_status.add_theme_color_override("font_color", Color.GREEN if p2_ready else Color.WHITE)


func _check_both_ready():
	if p1_ready and p2_ready and _countdown < 0:
		_countdown = 3.0
		countdown_label.show()


# ── Iniciar ────────────────────────────────────────────────

func _start_game():
	countdown_label.hide()

	var my_idx       = p1_cursor
	var opponent_idx = GameData.opponent_char_index

	if not _is_online:
		GameData.p1_stats = characters[p1_cursor]
		GameData.p1_scene = character_scenes[p1_cursor] if p1_cursor < character_scenes.size() else character_scenes[0]
		GameData.p2_stats = characters[p2_cursor]
		GameData.p2_scene = character_scenes[p2_cursor] if p2_cursor < character_scenes.size() else character_scenes[0]
	elif GameData.is_host:
		# Soy P1: mis stats → p1, oponente → p2
		GameData.p1_stats = characters[my_idx]
		GameData.p1_scene = character_scenes[my_idx] if my_idx < character_scenes.size() else character_scenes[0]
		GameData.p2_stats = characters[opponent_idx]
		GameData.p2_scene = character_scenes[opponent_idx] if opponent_idx < character_scenes.size() else character_scenes[0]
	else:
		# Soy P2: oponente → p1, mis stats → p2
		GameData.p1_stats = characters[opponent_idx]
		GameData.p1_scene = character_scenes[opponent_idx] if opponent_idx < character_scenes.size() else character_scenes[0]
		GameData.p2_stats = characters[my_idx]
		GameData.p2_scene = character_scenes[my_idx] if my_idx < character_scenes.size() else character_scenes[0]

	get_tree().change_scene_to_file("res://scenes/game.tscn")
