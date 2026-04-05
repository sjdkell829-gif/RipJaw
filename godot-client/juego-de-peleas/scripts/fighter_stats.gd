extends Resource
class_name FighterStats

@export_group("Movimiento")
@export var move_speed: float = 250.0
@export var jump_force: float = -600.0
@export var weight: float = 1.0

@export_group("Combate")
@export var attack_damage: int = 10
@export var knockback_power: float = 300.0
@export var attack_cooldown: float = 0.4

@export_group("Especial")
@export var has_special: bool = false
@export var special_damage: int = 30
@export var special_cooldown: float = 2.0
@export var projectile_scene: PackedScene

@export_group("Visual")
@export var character_name: String = "Luchador"
@export var portrait: Texture2D
@export var color: Color = Color.WHITE
@export var faces_right: bool = true  # false si el sprite mira a la izquierda por defecto

@export_group("Sonidos")
@export var sfx_jump: AudioStream
@export var sfx_attack: AudioStream
@export var sfx_hit: AudioStream
@export var sfx_death: AudioStream
@export var sfx_land: AudioStream
@export var sfx_special: AudioStream
