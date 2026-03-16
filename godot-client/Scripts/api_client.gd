# ============================================================
#   SmashAPI — api_client.gd
#   Maneja todas las llamadas HTTP REST al servidor Perl
#   Agregar como AutoLoad en Project > Project Settings > AutoLoad
# ============================================================

extends Node

const BASE_URL = "https://ripjaw-production.up.railway.app"

var token: String = ""
var local_player_id: int = 0
var local_username: String = ""

signal login_success(data)
signal login_error(msg)
signal register_success(data)
signal register_error(msg)
signal queue_result(data)
signal ranking_ready(data)
signal result_saved()


func _ready():
	token = ProjectSettings.get_setting("user_token", "")


# ── Helpers HTTP ───────────────────────────────────────────

func _post(endpoint: String, body: Dictionary, auth: bool = false) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var json_body = JSON.stringify(body)
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_POST, json_body)
	return http


func _get(endpoint: String, auth: bool = false) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_GET)
	return http


func _delete(endpoint: String) -> HTTPRequest:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]
	http.request(BASE_URL + endpoint, headers, HTTPClient.METHOD_DELETE)
	return http


func _parse(body: PackedByteArray) -> Dictionary:
	var text = body.get_string_from_utf8()
	var result = JSON.parse_string(text)
	if result is Dictionary:
		return result
	return {}


# ── Auth ───────────────────────────────────────────────────

func register(username: String, email: String, password: String):
	var http = _post("/api/auth/register", {
		"username": username,
		"email": email,
		"password": password
	})
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _parse(body)
		if code == 201:
			_save_token(data.get("token", ""))
			local_player_id = data.get("player_id", 0)
			local_username  = data.get("username", "")
			register_success.emit(data)
		else:
			register_error.emit(data.get("error", "Error desconocido"))
	)


func login(username: String, password: String):
	var http = _post("/api/auth/login", {
		"username": username,
		"password": password
	})
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _parse(body)
		if code == 200:
			_save_token(data.get("token", ""))
			local_player_id = data.get("player_id", 0)
			local_username  = data.get("username", "")
			login_success.emit(data)
		else:
			login_error.emit(data.get("error", "Credenciales incorrectas"))
	)


# ── Matchmaking ────────────────────────────────────────────

func join_queue():
	var http = _post("/api/matchmaking/queue", {}, true)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _parse(body)
		queue_result.emit(data)
	)


func leave_queue():
	var http = _delete("/api/matchmaking/queue")
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
	)


# ── Ranking ────────────────────────────────────────────────

func get_ranking():
	var http = _get("/api/players/ranking")
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		var data = _parse(body)
		ranking_ready.emit(data.get("ranking", []))
	)


# ── Match Result ───────────────────────────────────────────

func report_result(room_id: String, winner_id: int, loser_id: int):
	var http = _post("/api/match/result", {
		"room_id": room_id,
		"winner_id": winner_id,
		"loser_id": loser_id
	}, true)
	http.request_completed.connect(func(_r, _c, _h, _b):
		http.queue_free()
		result_saved.emit()
	)


# ── Utilidades ─────────────────────────────────────────────

func _save_token(t: String):
	token = t
	ProjectSettings.set_setting("user_token", t)