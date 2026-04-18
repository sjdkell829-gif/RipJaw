# ============================================================
#   SmashAPI — api_client.gd
# ============================================================
extends Node

const BASE_URL = "https://ripjaw.onrender.com"

var token:            String = ""
var local_player_id:  int    = 0
var local_username:   String = ""

signal login_success(data)
signal login_error(msg)
signal register_success(data)
signal register_error(msg)
signal queue_result(data)
signal ranking_ready(data)
signal result_saved()


func _ready():
	token = ProjectSettings.get_setting("user_token", "")
	if token != "":
		_restore_session()


func _restore_session():
	var http = _http_get("/api/auth/me", true)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if code == 200:
			var data        = _http_parse(body)
			local_player_id = data.get("id", 0)
			local_username  = data.get("username", "")
			# ── Sincronizar con GameData ──
			GameData.is_online = false
			print("Sesión restaurada: ", local_username, " id:", local_player_id)
		else:
			token           = ""
			local_player_id = 0
			ProjectSettings.set_setting("user_token", "")
	)


# ── Helpers HTTP ───────────────────────────────────────────

func _http_post(endpoint: String, body: Dictionary, auth: bool = false) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	return http


func _http_get(endpoint: String, auth: bool = false) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_GET)
	return http


func _http_delete(endpoint: String, body: Dictionary = {}) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_DELETE, JSON.stringify(body))
	return http


func _http_parse(body: PackedByteArray) -> Dictionary:
	var text   = body.get_string_from_utf8()
	var result = JSON.parse_string(text)
	if result is Dictionary:
		return result
	return {}


# ── Auth ───────────────────────────────────────────────────

func register(username: String, email: String, password: String):
	var http = _http_post("/api/auth/register", {
		"username": username,
		"email":    email,
		"password": password
	})
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _http_parse(body)
		if code == 201:
			_save_token(data.get("token", ""))
			local_player_id = data.get("player_id", 0)
			local_username  = data.get("username", "")
			GameData.is_online = false
			register_success.emit(data)
		else:
			register_error.emit(data.get("error", "Error desconocido"))
	)


func login(username: String, password: String):
	var http = _http_post("/api/auth/login", {
		"username": username,
		"password": password
	})
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _http_parse(body)
		if code == 200:
			_save_token(data.get("token", ""))
			local_player_id = data.get("player_id", 0)
			local_username  = data.get("username", "")
			GameData.is_online = false
			login_success.emit(data)
		else:
			login_error.emit(data.get("error", "Credenciales incorrectas"))
	)


# ── Matchmaking ────────────────────────────────────────────

func join_queue(stocks: int = 3):
	var http = _http_post("/api/matchmaking/queue", { "stocks": stocks }, true)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _http_parse(body)
		queue_result.emit(data)
	)


func leave_queue():
	var http = _http_delete("/api/matchmaking/queue")
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
	)


func cleanup_room(room_id: String):
	var http = _http_delete("/api/match/room", { "room_id": room_id })
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
	)


# ── Ranking ────────────────────────────────────────────────

func get_ranking():
	var http = _http_get("/api/players/ranking")
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _http_parse(body)
		ranking_ready.emit(data.get("ranking", []))
	)


# ── Match Result ───────────────────────────────────────────

func report_result(room_id: String, winner_id: int, loser_id: int):
	var http = _http_post("/api/match/result", {
		"room_id":   room_id,
		"winner_id": winner_id,
		"loser_id":  loser_id
	}, true)
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
		result_saved.emit()
	)


# ── Utilidades ─────────────────────────────────────────────

func _save_token(t: String):
	token = t
	ProjectSettings.set_setting("user_token", t)
	ProjectSettings.save()
