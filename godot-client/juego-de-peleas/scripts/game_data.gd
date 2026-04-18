extends Node

# ── Partida ────────────────────────────────────────────────
var stocks:   int  = 3
var vs_bot:   bool = false

# ── Personajes ─────────────────────────────────────────────
var p1_stats: FighterStats = null
var p2_stats: FighterStats = null
var p1_scene: String = "res://scenes/player_deku.tscn"
var p2_scene: String = "res://scenes/player_deku.tscn"

# ── Sesión ─────────────────────────────────────────────────
var is_guest:    bool   = false
var guest_id:    String = ""
var p1_username: String = "P1"
var p2_username: String = "P2"

# ── Online ─────────────────────────────────────────────────
var is_online:            bool   = false
var is_host:              bool   = false
var room_id:              String = ""
var ws_url:               String = ""
var opponent_id:          int    = 0
var opponent_char_index:  int    = 0
var opponent_username:    String = "Oponente"
