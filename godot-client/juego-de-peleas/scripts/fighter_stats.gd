extends Resource
class_name FighterStats

@export_group("Movimiento")
@export var move_speed: float = 250.0
@export var jump_force: float = -600.0
@export var weight: float = 1.0 # 1.0 es normal, más alto es más pesado (cae más rápido)

@export_group("Combate")
@export var attack_damage: int = 10
@export var knockback_power: float = 300.0
@export var attack_cooldown: float = 0.4

@export_group("Visual")
@export var character_name: String = "Luchador"
@export var portrait: Texture2D # Para el HUD más adelante
