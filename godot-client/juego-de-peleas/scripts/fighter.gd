# ============================================================
#   SmashAPI — fighter.gd
#   Adjuntar a un CharacterBody2D
# ============================================================
extends CharacterBody2D

@export var move_speed: float      = 200.0
@export var jump_force: float      = -500.0
@export var attack_damage: int     = 15
@export var knockback_force: float = 300.0
@export var player_id: int         = 1
@export var is_local_player: bool  = false

var damage_percent: float = 0.0
var stocks: int = 3
var can_attack: bool = true
var facing_direction: float = 1.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

signal took_damage(pid, percent)
signal died(pid)

var _actions: Dictionary = {}
var _current_anim: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	if player_id == 1:
		# Player 1 usa WASD + F
		_actions = {
			"left":   "p1_left",
			"right":  "p1_right",
			"jump":   "p1_jump",
			"attack": "p1_attack",
		}
		facing_direction = 1.0
	else:
		# Player 2 usa flechas + Enter
		_actions = {
			"left":   "p2_left",
			"right":  "p2_right",
			"jump":   "p2_jump",
			"attack": "p2_attack",
		}
		facing_direction = -1.0
	scale.x = facing_direction

	if sprite:
		sprite.play("idle")
	else:
		print("ERROR: No se encontró AnimatedSprite2D en player_id: ", player_id)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	if is_local_player:
		_handle_input()
	move_and_slide()
	_update_animation()
	_check_out_of_bounds()


func _handle_input():
	var dir = Input.get_axis(_actions["left"], _actions["right"])
	velocity.x = dir * move_speed
	if dir > 0:
		scale.x = 1.0
	elif dir < 0:
		scale.x = -1.0
	if Input.is_action_just_pressed(_actions["jump"]) and is_on_floor():
		velocity.y = jump_force
	if Input.is_action_just_pressed(_actions["attack"]) and can_attack:
		_do_attack()


func _update_animation():
	if not sprite:
		return
	if _current_anim == "attack" and sprite.is_playing():
		return
	var new_anim: String
	if not is_on_floor():
		new_anim = "jump"
	elif abs(velocity.x) > 10:
		new_anim = "run"
	else:
		new_anim = "idle"
	if new_anim != _current_anim:
		_current_anim = new_anim
		sprite.play(new_anim)


func _do_attack():
	can_attack = false
	_current_anim = "attack"
	if sprite:
		sprite.play("attack")
		await sprite.animation_finished
		_current_anim = ""
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 60.0
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	var results = space.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body == self:
			continue
		if body.has_method("take_hit"):
			body.take_hit(attack_damage, global_position)
	await get_tree().create_timer(0.3).timeout
	can_attack = true


func take_hit(damage: int, source_pos: Vector2):
	damage_percent += damage
	var multiplier = 1.0 + (damage_percent / 100.0)
	var direction = (global_position - source_pos).normalized()
	velocity += direction * knockback_force * multiplier
	took_damage.emit(player_id, damage_percent)


func apply_remote_state(data: Dictionary):
	if data.get("type") == "input":
		velocity.x = float(data.get("x", 0.0)) * move_speed
		if data.get("jumping", false) and is_on_floor():
			velocity.y = jump_force
		if data.get("attacking", false) and can_attack:
			_do_attack()


func _check_out_of_bounds():
	if position.y > 800 or abs(position.x) > 1200:
		_die()


func _die():
	stocks -= 1
	died.emit(player_id)
	if stocks > 0:
		await get_tree().create_timer(2.0).timeout
		position = Vector2(576, 300)
		velocity = Vector2.ZERO
		damage_percent = 0.0
		if sprite:
			sprite.play("idle")
		_current_anim = ""
