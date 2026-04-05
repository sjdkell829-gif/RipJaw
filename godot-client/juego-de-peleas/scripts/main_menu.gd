extends Control

var login_panel: Panel
var main_panel: Panel

var username_input: LineEdit
var password_input: LineEdit
var login_error: Label
var welcome_label: Label
var elo_label: Label


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_panel(login_panel)
	ApiClient.login_success.connect(_on_login_success)
	ApiClient.login_error.connect(_on_login_error)
	ApiClient.register_success.connect(_on_login_success)
	ApiClient.register_error.connect(_on_login_error)
	if ApiClient.local_player_id != 0:
		_show_panel(main_panel)
		welcome_label.text = "¡Hola, %s!" % ApiClient.local_username
		elo_label.text     = "ELO: ..."
		_load_elo()


func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_login_panel()
	_build_main_panel()


func _build_login_panel():
	login_panel = Panel.new()
	login_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(login_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(376, 80)
	vbox.custom_minimum_size = Vector2(400, 500)
	vbox.add_theme_constant_override("separation", 14)
	login_panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚡ RIPJAW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var quick_btn = Button.new()
	quick_btn.text = "🎮 Jugar sin cuenta"
	quick_btn.custom_minimum_size = Vector2(400, 55)
	quick_btn.add_theme_font_size_override("font_size", 18)
	quick_btn.pressed.connect(_on_quick_play_pressed)
	vbox.add_child(quick_btn)

	vbox.add_child(HSeparator.new())

	var or_label = Label.new()
	or_label.text = "— o inicia sesión —"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(or_label)

	username_input = LineEdit.new()
	username_input.placeholder_text = "Usuario"
	username_input.custom_minimum_size = Vector2(400, 40)
	vbox.add_child(username_input)

	password_input = LineEdit.new()
	password_input.placeholder_text = "Contraseña"
	password_input.secret = true
	password_input.custom_minimum_size = Vector2(400, 40)
	vbox.add_child(password_input)

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
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(376, 100)
	vbox.custom_minimum_size = Vector2(400, 400)
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

	var local_btn = Button.new()
	local_btn.text = "🎮 Jugar local"
	local_btn.custom_minimum_size = Vector2(400, 55)
	local_btn.add_theme_font_size_override("font_size", 18)
	local_btn.pressed.connect(_on_quick_play_pressed)
	vbox.add_child(local_btn)

	var fight_btn = Button.new()
	fight_btn.text = "⚔ Pelear online"
	fight_btn.custom_minimum_size = Vector2(400, 55)
	fight_btn.add_theme_font_size_override("font_size", 18)
	fight_btn.pressed.connect(_on_fight_pressed)
	vbox.add_child(fight_btn)

	var ranking_btn = Button.new()
	ranking_btn.text = "🏆 Ranking"
	ranking_btn.custom_minimum_size = Vector2(400, 44)
	ranking_btn.pressed.connect(_on_ranking_pressed)
	vbox.add_child(ranking_btn)

	var logout_btn = Button.new()
	logout_btn.text = "Cerrar sesión"
	logout_btn.custom_minimum_size = Vector2(400, 40)
	logout_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)


func _show_panel(panel: Panel):
	login_panel.visible = (panel == login_panel)
	main_panel.visible  = (panel == main_panel)


func _load_elo():
	var http = ApiClient._http_get("/api/auth/me", true)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if code == 200:
			var data = ApiClient._http_parse(body)
			elo_label.text = "ELO: %d" % data.get("elo", 1000)
	)


func _on_quick_play_pressed():
	GameData.room_id     = ""
	GameData.ws_url      = ""
	GameData.opponent_id = 0
	get_tree().change_scene_to_file("res://scenes/match_config.tscn")


func _on_fight_pressed():
	GameData.room_id     = ""
	GameData.ws_url      = ""
	GameData.opponent_id = 0
	get_tree().change_scene_to_file("res://scenes/match_config.tscn")


func _on_login_pressed():
	login_error.text = ""
	ApiClient.login(username_input.text.strip_edges(), password_input.text)


func _on_register_pressed():
	login_error.text = ""
	var email = username_input.text.strip_edges() + "@ripjaw.com"
	ApiClient.register(username_input.text.strip_edges(), email, password_input.text)


func _on_login_success(data: Dictionary):
	welcome_label.text = "¡Hola, %s!" % data.get("username", "")
	elo_label.text     = "ELO: %d" % data.get("elo", 1000)
	_show_panel(main_panel)


func _on_login_error(msg: String):
	login_error.text = msg


func _on_logout_pressed():
	ApiClient.token           = ""
	ApiClient.local_player_id = 0
	ApiClient.local_username  = ""
	ProjectSettings.set_setting("user_token", "")
	ProjectSettings.save()
	_show_panel(login_panel)


func _on_ranking_pressed():
	ApiClient.get_ranking()
