# ============================================================
#   SmashAPI — main_menu.gd
#   Adjuntar al nodo raíz de la escena res://scenes/main_menu.tscn
# ============================================================

extends Control

# ── Paneles ────────────────────────────────────────────────
@onready var login_panel:    Control = $LoginPanel
@onready var main_panel:     Control = $MainPanel
@onready var searching_panel: Control = $SearchingPanel
@onready var ranking_panel:  Control = $RankingPanel

# ── Login ──────────────────────────────────────────────────
@onready var username_input: LineEdit = $LoginPanel/UsernameInput
@onready var password_input: LineEdit = $LoginPanel/PasswordInput
@onready var login_error:    Label    = $LoginPanel/ErrorLabel

# ── Main ───────────────────────────────────────────────────
@onready var welcome_label: Label = $MainPanel/WelcomeLabel
@onready var elo_label:     Label = $MainPanel/EloLabel

# ── Matchmaking ────────────────────────────────────────────
@onready var searching_label: Label = $SearchingPanel/SearchingLabel

var _searching: bool  = false
var _search_timer: float = 0.0
var _dots: int = 0


func _ready():
	_show_panel(login_panel)

	# Conectar señales de la API
	ApiClient.login_success.connect(_on_login_success)
	ApiClient.login_error.connect(_on_login_error)
	ApiClient.queue_result.connect(_on_queue_result)
	ApiClient.ranking_ready.connect(_on_ranking_ready)


func _process(delta):
	if not _searching:
		return

	# Polling del matchmaking cada 2 segundos
	_search_timer += delta
	if _search_timer >= 2.0:
		_search_timer = 0.0
		_dots = (_dots + 1) % 4
		searching_label.text = "Buscando oponente" + ".".repeat(_dots)
		ApiClient.join_queue()


# ── Navegación ─────────────────────────────────────────────

func _show_panel(panel: Control):
	for p in [login_panel, main_panel, searching_panel, ranking_panel]:
		p.visible = (p == panel)


# ── Botones de Login ───────────────────────────────────────

func _on_login_pressed():
	login_error.text = ""
	ApiClient.login(username_input.text.strip_edges(), password_input.text)


func _on_register_pressed():
	login_error.text = ""
	# Para simplificar, el email es username@smash.com
	var email = username_input.text.strip_edges() + "@smash.com"
	ApiClient.register(username_input.text.strip_edges(), email, password_input.text)


func _on_login_success(data: Dictionary):
	welcome_label.text = "¡Hola, %s!" % data.get("username", "")
	elo_label.text     = "ELO: %d" % data.get("elo", 1000)
	_show_panel(main_panel)


func _on_login_error(msg: String):
	login_error.text = msg


# ── Botones del menú principal ─────────────────────────────

func _on_fight_pressed():
	_searching = true
	_search_timer = 2.0   # Buscar inmediatamente en el primer tick
	_show_panel(searching_panel)


func _on_cancel_search_pressed():
	_searching = false
	ApiClient.leave_queue()
	_show_panel(main_panel)


func _on_ranking_pressed():
	_show_panel(ranking_panel)
	ApiClient.get_ranking()


func _on_back_ranking_pressed():
	_show_panel(main_panel)


# ── Matchmaking ────────────────────────────────────────────

func _on_queue_result(data: Dictionary):
	if data.get("status") == "match_found":
		_searching = false
		searching_label.text = "¡Oponente encontrado! Cargando..."

		# Pasar datos a la escena de juego
		GameData.room_id     = data.get("room_id", "")
		GameData.ws_url      = data.get("ws_url", "")
		GameData.opponent_id = data.get("opponent_id", 0)

		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/game.tscn")


# ── Ranking ────────────────────────────────────────────────

@onready var ranking_container: VBoxContainer = $RankingPanel/RankingContainer

func _on_ranking_ready(players: Array):
	# Limpiar lista anterior
	for child in ranking_container.get_children():
		child.queue_free()

	# Crear una fila por jugador
	for i in players.size():
		var p    = players[i]
		var row  = Label.new()
		row.text = "#%d  %s  —  ELO: %d  (%dW / %dL)" % [
			i + 1,
			p.get("username", "?"),
			p.get("elo", 0),
			p.get("wins", 0),
			p.get("losses", 0)
		]
		ranking_container.add_child(row)