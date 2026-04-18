# ============================================================
#   RipJaw — ray_gun_projectile.gd
#   Proyectil de la Ray Gun de Richtofen
# ============================================================
extends Area2D

var speed: float   = 800.0
var damage: int    = 30
var direction: float = 1.0
var owner_id: int  = 0


func setup(dir: float, pid: int, dmg: int):
	direction = dir
	owner_id  = pid
	damage    = dmg


func _ready():
	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)
	# Visual temporal — rayo verde
	var rect       = ColorRect.new()
	rect.color     = Color(0.0, 1.0, 0.3, 0.9)
	rect.size      = Vector2(30, 8)
	rect.position  = Vector2(-15, -4)
	add_child(rect)
	# Voltear si va a la izquierda
	scale.x = direction


func _physics_process(delta):
	position.x += direction * speed * delta
	if abs(position.x) > 2000:
		queue_free()


func _on_body_entered(body):
	if body.has_method("take_hit") and body.get("player_id") != owner_id:
		body.take_hit(damage, global_position)
		# Efecto de explosión simple
		_explode()


func _explode():
	# Flash verde al impactar
	var flash      = ColorRect.new()
	flash.color    = Color(0.0, 1.0, 0.302, 0.494)
	flash.size     = Vector2(40, 40)
	flash.position = Vector2(-20, -20)
	get_parent().add_child(flash)
	flash.global_position = global_position
	# Destruir flash después de un momento
	await get_tree().create_timer(0.1).timeout
	flash.queue_free()
	queue_free()
