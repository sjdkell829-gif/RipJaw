# ============================================================
#   SmashAPI — main_menu.gd
#   UI generada por código, sin necesidad de nodos manuales
# ============================================================

extends Control

# ── Variables de estado ────────────────────────────────────
var _searching: bool = false
var _search_timer: float = 0.0
var _dots: int = 0

# ── Nodos UI (creados por código) ──────────────────────────
var login_panel: Panel
var main_panel: Panel
var searching_panel: Panel

var username_input: LineEdit
var password_input: LineEdit
var login_error: Label
var welcome_label: Label
var elo_label: Label
var searching_label: Label


func _ready():
	# Hacer que ocupe toda la pantalla
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_build_ui()
	_show_panel(login_panel)
	
	# Conectar señales de la API
	ApiClient.login_success.connect(_on_login_success)
	ApiClient.login_error.connect(_on_login_error)
	ApiClient.register_success.connect(_on_login_success)
	ApiClient.register_error.connect(_on_login_error)
	ApiClient.queue_result.connect(_on_queue_result)


func _process(delta):
	if not _searching:
		return
	_search_timer += delta
	if _search_timer >= 2.0:
		_search_timer = 0.0
		_dots = (_dots + 1) % 4
		searching_label.text = "Buscando oponente" + ".".repeat(_dots)
		ApiClient.join_queue()


# ── Construir UI por código ────────────────────────────────

func _build_ui():
	# Fondo negro
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_login_panel()
	_build_main_panel()
	_build_searching_panel()


func _build_login_panel():
	login_panel = Panel.new()
	login_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(login_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.position = Vector2(-200, -150)
	vbox.add_theme_constant_override("separation", 16)
	login_panel.add_child(vbox)

	# Título
	var title = Label.new()
	title.text = "⚡ RIPJAW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	# Username
	username_input = LineEdit.new()
	username_input.placeholder_text = "Usuario"
	username_input.custom_minimum_size = Vector2(400, 40)
	vbox.add_child(username_input)

	# Password
	password_input = LineEdit.new()
	password_input.placeholder_text = "Contraseña"
	password_input.secret = true
	password_input.custom_minimum_size = Vector2(400, 40)
	vbox.add_child(password_input)

	# Botones
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var login_btn = Button.new()
	login_btn.text = "Entrar"
	login_btn.custom_minimum_size = Vector2(190, 44)
	login_btn.pressed.connect(_on_login_pressed)
	hbox.add_child(login_btn)

	var register_btn = Button.new()
	register_btn.text = "Registrarse"
	register_btn.custom_minimum_size = Vector2(190, 44)
	register_btn.pressed.connect(_on_register_pressed)
	hbox.add_child(register_btn)

	# Error label
	login_error = Label.new()
	login_error.text = ""
	login_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_error.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(login_error)


func _build_main_panel():
	main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.position = Vector2(-200, -150)
	vbox.add_theme_constant_override("separation", 20)
	main_panel.add_child(vbox)

	welcome_label = Label.new()
	welcome_label.text = "¡Bienvenido!"
	welcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(welcome_label)

	elo_label = Label.new()
	elo_label.text = "ELO: 1000"
	elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(elo_label)

	var fight_btn = Button.new()
	fight_btn.text = "⚔ PELEAR"
	fight_btn.custom_minimum_size = Vector2(400, 60)
	fight_btn.add_theme_font_size_override("font_size", 22)
	fight_btn.pressed.connect(_on_fight_pressed)
	vbox.add_child(fight_btn)

	var ranking_btn = Button.new()
	ranking_btn.text = "🏆 Ranking"
	ranking_btn.custom_minimum_size = Vector2(400, 44)
	ranking_btn.pressed.connect(_on_ranking_pressed)
	vbox.add_child(ranking_btn)


func _build_searching_panel():
	searching_panel = Panel.new()
	searching_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(searching_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 200)
	vbox.position = Vector2(-200, -100)
	vbox.add_theme_constant_override("separation", 20)
	searching_panel.add_child(vbox)

	searching_label = Label.new()
	searching_label.text = "Buscando oponente..."
	searching_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	searching_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(searching_label)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(400, 44)
	cancel_btn.pressed.connect(_on_cancel_search_pressed)
	vbox.add_child(cancel_btn)


# ── Navegación ─────────────────────────────────────────────

func _show_panel(panel: Panel):
	login_panel.visible    = (panel == login_panel)
	main_panel.visible     = (panel == main_panel)
	searching_panel.visible = (panel == searching_panel)


# ── Eventos ────────────────────────────────────────────────

func _on_login_pressed():
	login_error.text = ""
	ApiClient.login(username_input.text.strip_edges(), password_input.text)


func _on_register_pressed():
	login_error.text = ""
	var email = username_input.text.strip_edges() + "@ripjaw.com"
	ApiClient.register(username_input.text.strip_edges(), email, password_input.text)


func _on_login_success(data: Dictionary):
	welcome_label.text = "¡Hola, %s!" % data.get("username", "")
	elo_label.text = "ELO: %d" % data.get("elo", 1000)
	_show_panel(main_panel)


func _on_login_error(msg: String):
	login_error.text = msg


func _on_fight_pressed():
	_searching = true
	_search_timer = 2.0
	_show_panel(searching_panel)


func _on_cancel_search_pressed():
	_searching = false
	ApiClient.leave_queue()
	_show_panel(main_panel)


func _on_ranking_pressed():
	ApiClient.get_ranking()


func _on_queue_result(data: Dictionary):
	if data.get("status") == "match_found":
		_searching = false
		searching_label.text = "¡Oponente encontrado! Cargando..."
		GameData.room_id     = data.get("room_id", "")
		GameData.ws_url      = data.get("ws_url", "")
		GameData.opponent_id = data.get("opponent_id", 0)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/game.tscn")
