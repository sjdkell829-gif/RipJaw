# ============================================================
#   RipJaw — match_config.gd
#   Pantalla de configuración de partida
# ============================================================
extends Control

var _stocks:  int  = 3
var _vs_bot:  bool = false

# Online
var _searching:      bool  = false
var _poll_timer:     float = 0.0
const POLL_INTERVAL: float = 2.0

var stocks_value:  Label
var minus_btn:     Button
var plus_btn:      Button
var bot_check:     CheckBox
var online_btn:    Button
var status_label:  Label
var cancel_btn:    Button


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stocks = GameData.stocks
	_vs_bot = GameData.vs_bot
	_build_ui()


func _process(delta):
	if not _searching:
		return
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_poll_matchmaking()


func _build_ui():
	# Fondo
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel central
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 480)
	panel.position = Vector2(-210, -240)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_left",   30)
	margin.add_theme_constant_override("margin_right",  30)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 24)
	margin.add_child(inner)

	# Título
	var title = Label.new()
	title.text = "⚔ Configuración de Partida"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	inner.add_child(title)

	inner.add_child(HSeparator.new())

	# ── Vidas ──────────────────────────────────────────────
	var stocks_label = Label.new()
	stocks_label.text = "Número de vidas (1-9):"
	stocks_label.add_theme_font_size_override("font_size", 16)
	inner.add_child(stocks_label)

	var stocks_row = HBoxContainer.new()
	stocks_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stocks_row.add_theme_constant_override("separation", 20)
	inner.add_child(stocks_row)

	minus_btn = Button.new()
	minus_btn.text = "  —  "
	minus_btn.custom_minimum_size = Vector2(60, 50)
	minus_btn.add_theme_font_size_override("font_size", 22)
	minus_btn.pressed.connect(_on_minus)
	stocks_row.add_child(minus_btn)

	stocks_value = Label.new()
	stocks_value.text = str(_stocks)
	stocks_value.custom_minimum_size = Vector2(60, 50)
	stocks_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stocks_value.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	stocks_value.add_theme_font_size_override("font_size", 32)
	stocks_row.add_child(stocks_value)

	plus_btn = Button.new()
	plus_btn.text = "  +  "
	plus_btn.custom_minimum_size = Vector2(60, 50)
	plus_btn.add_theme_font_size_override("font_size", 22)
	plus_btn.pressed.connect(_on_plus)
	stocks_row.add_child(plus_btn)

	inner.add_child(HSeparator.new())

	# ── Bot ────────────────────────────────────────────────
	var bot_row = HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 16)
	inner.add_child(bot_row)

	var bot_label = Label.new()
	bot_label.text = "Jugar vs Bot:"
	bot_label.add_theme_font_size_override("font_size", 16)
	bot_row.add_child(bot_label)

	bot_check = CheckBox.new()
	bot_check.button_pressed = _vs_bot
	bot_check.toggled.connect(_on_bot_toggled)
	bot_row.add_child(bot_check)

	inner.add_child(HSeparator.new())

	# ── Botón local ────────────────────────────────────────
	var start_btn = Button.new()
	start_btn.text = "¡A pelear! ⚔  (local)"
	start_btn.custom_minimum_size = Vector2(340, 55)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_start_local)
	inner.add_child(start_btn)

	# ── Botón online ───────────────────────────────────────
	online_btn = Button.new()
	online_btn.text = "🌐  Buscar partida online"
	online_btn.custom_minimum_size = Vector2(340, 55)
	online_btn.add_theme_font_size_override("font_size", 18)
	online_btn.pressed.connect(_on_search_online)
	inner.add_child(online_btn)

	# ── Estado de búsqueda ─────────────────────────────────
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	inner.add_child(status_label)

	cancel_btn = Button.new()
	cancel_btn.text = "✖ Cancelar búsqueda"
	cancel_btn.custom_minimum_size = Vector2(340, 38)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(_on_cancel_search)
	cancel_btn.visible = false
	inner.add_child(cancel_btn)

	# ── Volver ─────────────────────────────────────────────
	var back_btn = Button.new()
	back_btn.text = "← Volver"
	back_btn.custom_minimum_size = Vector2(340, 40)
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.pressed.connect(_on_back)
	inner.add_child(back_btn)

	_update_display()


# ── Controles de vidas ─────────────────────────────────────

func _update_display():
	stocks_value.text  = str(_stocks)
	minus_btn.disabled = (_stocks <= 1)
	plus_btn.disabled  = (_stocks >= 9)


func _on_minus():
	_stocks = max(1, _stocks - 1)
	_update_display()


func _on_plus():
	_stocks = min(9, _stocks + 1)
	_update_display()


func _on_bot_toggled(pressed: bool):
	_vs_bot = pressed
	GameData.vs_bot = pressed


# ── Local ──────────────────────────────────────────────────

func _on_start_local():
	GameData.stocks    = _stocks
	GameData.vs_bot    = _vs_bot
	GameData.is_online = false
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


# ── Online ─────────────────────────────────────────────────

func _on_search_online():
	print("=== TOKEN: ", ApiClient.token)
	print("=== PLAYER ID: ", ApiClient.local_player_id)
	
	if ApiClient.token == "":
		status_label.text = "⚠ Debes iniciar sesión primero."
		return
	# ... resto del código

	GameData.stocks    = _stocks
	GameData.vs_bot    = false
	GameData.is_online = true

	_searching          = true
	_poll_timer         = POLL_INTERVAL   # dispara en el primer frame
	online_btn.disabled = true
	cancel_btn.visible  = true
	status_label.text   = "🔍 Buscando oponente..."


func _on_cancel_search():
	_searching          = false
	online_btn.disabled = false
	cancel_btn.visible  = false
	status_label.text   = ""
	GameData.is_online  = false
	ApiClient.leave_queue()


func _poll_matchmaking():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_poll_response.bind(http))

	var headers = [
		"Authorization: Bearer " + ApiClient.token,
		"Content-Type: application/json"
	]
	http.request(
		"https://ripjaw-production-2299.up.railway.app/api/matchmaking/queue",
		headers,
		HTTPClient.METHOD_POST
	)


func _on_poll_response(_result, response_code, _headers, body, http: HTTPRequest):
	http.queue_free()

	if not _searching:
		return

	if response_code != 200 and response_code != 201:
		status_label.text = "⚠ Error del servidor (%d). Reintentando..." % response_code
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary:
		return

	match json.get("status", ""):

		"waiting":
			status_label.text = "🔍 Buscando oponente..."

		"match_found":
			_searching          = false
			cancel_btn.visible  = false
			online_btn.disabled = false
			status_label.text   = "✅ ¡Oponente encontrado!"

			GameData.room_id     = json.get("room_id",     "")
			GameData.ws_url      = json.get("ws_url",      "")
			GameData.opponent_id = json.get("opponent_id", 0)

			# is_p1 viene del servidor — fuente de verdad
			GameData.is_host = json.get("is_p1", false)

			get_tree().change_scene_to_file("res://scenes/character_select.tscn")


# ── Volver ─────────────────────────────────────────────────

func _on_back():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
