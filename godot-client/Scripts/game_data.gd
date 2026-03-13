# ============================================================
#   SmashAPI — game_data.gd
#   AutoLoad global para pasar datos entre escenas
#   Agregar en Project > Project Settings > AutoLoad como "GameData"
# ============================================================

extends Node

var room_id: String     = ""
var ws_url: String      = ""
var opponent_id: int    = 0