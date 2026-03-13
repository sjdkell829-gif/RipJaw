# ============================================================
#   SmashAPI — fighter.gd
#   Adjuntar a un CharacterBody2D
#   Lógica de movimiento, salto y ataques tipo Smash Bros
# ============================================================

extends CharacterBody2D

# ── Stats ──────────────────────────────────────────────────
@export var move_speed: float    = 200.0
@export var jump_force: float    = -500.0
@export var attack_damage: int   = 15
@export var knockback_force: float = 300.0

# ── Estado ─────────────────────────────────────────────────
@export var player_id: int       = 1
@export var is_local_player: bool = false

var damage_percent: float = 0.0   # 0% → 999% como en Smash
var stocks: int = 3
var can_attack: bool = true

# Gravedad del proyecto
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# ── Nodos hijos ────────────────────────────────────────────
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area2D   = $AttackArea
@onready var sprite: Sprite2D      = $Sprite2D

signal took_damage(player_id, percent)
signal died(player_id)


func _physics_process(delta):
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_local_player:
		_handle_input()

	move_and_slide()
	_check_out_of_bounds()


# ── Input local ────────────────────────────────────────────

func _handle_input():
	var dir = Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * move_speed

	# Voltear sprite
	if dir != 0:
		sprite.flip_h = dir < 0

	# Salto
	var jumping = false
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
		jumping = true
		anim.play("jump")

	# Ataque
	var attacking = false
	if Input.is_action_just_pressed("ui_select") and can_attack:
		attacking = true
		_do_attack()

	# Animación de movimiento
	if is_on_floor():
		if dir != 0:
			anim.play("run")
		else:
			anim.play("idle")

	# Enviar input al servidor
	WebSocketClient.send_input(dir, velocity.y, attacking, jumping)


# ── Ataque ─────────────────────────────────────────────────

func _do_attack():
	can_attack = false
	anim.play("attack")

	# Detectar enemigos en el área de ataque
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if body.has_method("take_hit"):
			body.take_hit(attack_damage, global_position)
			WebSocketClient.send_hit(body.player_id, attack_damage)

	await get_tree().create_timer(0.3).timeout
	can_attack = true


# ── Recibir golpe ──────────────────────────────────────────

func take_hit(damage: int, source_pos: Vector2):
	damage_percent += damage

	# Knockback escalado: más % = más lejos (mecánica de Smash)
	var multiplier = 1.0 + (damage_percent / 100.0)
	var direction  = (global_position - source_pos).normalized()
	velocity += direction * knockback_force * multiplier

	anim.play("hit")
	took_damage.emit(player_id, damage_percent)


# ── Aplicar estado del oponente (recibido por WebSocket) ───

func apply_remote_state(data: Dictionary):
	if data.get("type") == "input":
		velocity.x = float(data.get("x", 0.0)) * move_speed
		if data.get("jumping", false) and is_on_floor():
			velocity.y = jump_force
		if data.get("attacking", false) and can_attack:
			_do_attack()


# ── Muerte ─────────────────────────────────────────────────

func _check_out_of_bounds():
	# Si el personaje sale de la pantalla, muere
	if position.y > 800 or abs(position.x) > 1200:
		_die()


func _die():
	stocks -= 1
	anim.play("die")
	died.emit(player_id)

	if stocks > 0:
		# Reaparecer en el centro después de 2 segundos
		await get_tree().create_timer(2.0).timeout
		position = Vector2(0, 0)
		velocity = Vector2.ZERO
		damage_percent = 0.0