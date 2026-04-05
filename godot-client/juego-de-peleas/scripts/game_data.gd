extends Node

var room_id: String        = ""
var ws_url: String         = ""
var opponent_id: int       = 0
var p1_stats: FighterStats = null
var p2_stats: FighterStats = null
var p1_scene: String       = "res://scenes/player_deku.tscn"
var p2_scene: String       = "res://scenes/player_deku.tscn"
var stocks: int            = 3
var vs_bot: bool           = false
