# ============================================================
#   RipJaw — game_data.gd
#   AutoLoad global entre escenas
# ============================================================
extends Node

# ── Partida ────────────────────────────────────────────────
var stocks:   int  = 3
var vs_bot:   bool = false

# ── Personajes ─────────────────────────────────────────────
var p1_stats: FighterStats = null
var p2_stats: FighterStats = null
var p1_scene: String = "res://scenes/player_deku.tscn"
var p2_scene: String = "res://scenes/player_deku.tscn"

# ── Online ─────────────────────────────────────────────────
var is_online:   bool   = false
var is_host:     bool   = false   # true = soy P1 en el room
var room_id:     String = ""
var ws_url:      String = ""
var opponent_id: int    = 0

# ── Personaje del oponente (recibido por WS) ───────────────
var opponent_char_index: int = 0
