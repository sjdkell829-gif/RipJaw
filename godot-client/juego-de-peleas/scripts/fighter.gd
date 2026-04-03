extends CharacterBody2D

@export var stats: FighterStats
@export var player_id: int = 1
@export var is_local_player: bool = false

var damage_percent: float = 0.0
var stocks: int = 3
var can_attack: bool = true
var is_crouching: bool = false # Nueva variable para agacharse
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

signal took_damage(pid, percent)
signal died(pid)

var _actions: Dictionary = {}
var _current_anim: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	if stats == null:
		push_error("Fighter player_id=%d no tiene FighterStats asignado" % player_id)
		return
	_setup_actions()
	if sprite:
		sprite.play("idle")


func setup(pid: int, local: bool):
	player_id        = pid
	is_local_player = local
	_setup_actions()


func _setup_actions():
	if player_id == 1:
		_actions = {
			"left":   "p1_left",
			"right":  "p1_right",
			"jump":   "p1_jump",
			"attack": "p1_attack",
			"down":   "p1_down"
		}
	else:
		_actions = {
			"left":   "p2_left",
			"right":  "p2_right",
			"jump":   "p2_jump",
			"attack": "p2_attack",
			"down":   "p2_down"
		}


func _physics_process(delta):
	if stats == null:
		return
		
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * stats.weight * delta
		
	if is_local_player:
		_handle_input()
		
	move_and_slide()
	
	# Lógica de colisión entre jugadores (Empujar y Resbalar)
	_handle_player_collision(delta)
	
	_update_animation()
	_check_out_of_bounds()


func _handle_input():
	# Determinar si se está agachando
	is_crouching = Input.is_action_pressed(_actions["down"]) and is_on_floor()
	
	var dir = Input.get_axis(_actions["left"], _actions["right"])
	
	if is_crouching:
		# Si está agachado, se mueve muy lento o se queda quieto
		velocity.x = move_toward(velocity.x, 0, stats.move_speed * 0.5)
	elif dir != 0:
		velocity.x = dir * stats.move_speed
		sprite.flip_h = (dir > 0)
	else:
		velocity.x = move_toward(velocity.x, 0, stats.move_speed * 0.2)

	# Solo saltar o atacar si NO está agachado (puedes cambiar esto después)
	if Input.is_action_just_pressed(_actions["jump"]) and is_on_floor() and not is_crouching:
		velocity.y = stats.jump_force

	if Input.is_action_just_pressed(_actions["attack"]) and can_attack and not is_crouching:
		_do_attack()


func _handle_player_collision(delta):
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is CharacterBody2D and collider != self:
			if "player_id" in collider:
				# 1. Si estamos encima del otro (resbalar)
				if global_position.y < collider.global_position.y - 25:
					var slide_dir = sign(global_position.x - collider.global_position.x)
					if slide_dir == 0: slide_dir = 1
					global_position.x += slide_dir * 300.0 * delta
				
				# 2. Si estamos a los lados (empujar)
				else:
					var push_dir = sign(collider.global_position.x - global_position.x)
					# Solo empujamos si nos movemos hacia él o estamos pegados
					if sign(velocity.x) == push_dir or velocity.x == 0:
						collider.global_position.x += push_dir * 120.0 * delta


func _update_animation():
	if not sprite:
		return
	if _current_anim == "attack" and sprite.is_playing():
		return
		
	var new_anim: String
	if not is_on_floor():
		new_anim = "jump"
	elif is_crouching:
		new_anim = "crouch" # Asegúrate de tener esta animación en tu Sprite
	else:
		var input_dir = Input.get_axis(_actions["left"], _actions["right"])
		if input_dir != 0 and abs(velocity.x) > 50:
			new_anim = "run"
		else:
			new_anim = "idle"
			
	if new_anim != _current_anim:
		_current_anim = new_anim
		sprite.play(new_anim)


func _do_attack():
	can_attack = false
	_current_anim = "attack"
	sprite.play("attack")
	
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 70.0
	var side = 1 if sprite.flip_h else -1
	var attack_offset = Vector2(60 * side, 0)
	
	query.shape = shape
	query.transform = global_transform
	query.transform.origin += attack_offset
	query.collision_mask = 1
	
	var results = space.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body != self and body.has_method("take_hit"):
			body.take_hit(stats.attack_damage, global_position)
			
	await sprite.animation_finished
	_current_anim = ""
	await get_tree().create_timer(stats.attack_cooldown).timeout
	can_attack = true


func take_hit(damage: int, source_pos: Vector2):
	damage_percent += damage
	var multiplier = 1.0 + (damage_percent / 100.0)
	var direction = (global_position - source_pos).normalized()
	direction.y -= 0.45
	velocity = direction.normalized() * stats.knockback_power * multiplier
	took_damage.emit(player_id, damage_percent)


func apply_remote_state(data: Dictionary):
	if data.get("type") == "input":
		velocity.x = float(data.get("x", 0.0)) * (stats.move_speed if stats else 200.0)
		if data.get("jumping", false) and is_on_floor():
			velocity.y = stats.jump_force if stats else -500.0
		if data.get("attacking", false) and can_attack:
			_do_attack()


func _check_out_of_bounds():
	if position.y > 1000 or abs(position.x) > 1800:
		_die()


func _die():
	stocks -= 1
	died.emit(player_id)
	if stocks > 0:
		await get_tree().create_timer(1.5).timeout
		position = Vector2(576, 150)
		velocity = Vector2.ZERO
		damage_percent = 0.0
		took_damage.emit(player_id, 0.0)
		if sprite:
			sprite.play("idle")
		_current_anim = ""
		show()
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
