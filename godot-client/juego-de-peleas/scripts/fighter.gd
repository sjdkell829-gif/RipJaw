extends CharacterBody2D

@export var stats: FighterStats
@export var player_id: int = 1
@export var is_local_player: bool = false

var slot: int = 1
var username: String = ""
var _name_label: Label = null

# Interpolación remota
var _target_pos: Vector2 = Vector2.ZERO
var _target_vel: Vector2 = Vector2.ZERO
var _has_remote_target: bool = false

var damage_percent: float = 0.0
var stocks: int = 3
var can_attack: bool = true
var can_special: bool = true
var is_crouching: bool = false
var _was_on_floor: bool = true
var _special_cooldown_timer: float = 0.0
var _facing: float = 1.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

signal took_damage(pid, percent)
signal died(pid)

var _actions: Dictionary = {}
var _current_anim: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready():
	_apply_stats_from_slot()
	if stats == null:
		push_error("Fighter slot=%d no tiene FighterStats asignado" % slot)
		return
	_setup_actions()
	_facing = 1.0 if stats.faces_right else -1.0
	scale.x = 1.0
	sprite.scale.x = _facing
	if sprite:
		sprite.play("idle")


func setup(pid: int, local: bool, p_slot: int = 1):
	player_id       = pid
	is_local_player = local
	slot            = p_slot
	_apply_stats_from_slot()
	_setup_actions()
	if stats:
		_facing = 1.0 if stats.faces_right else -1.0
		scale.x = 1.0
		sprite.scale.x = _facing
	if sprite and stats:
		sprite.play("idle")
	if slot == 1:
		username = GameData.p1_username
	else:
		username = GameData.opponent_username if GameData.is_online else GameData.p2_username
	_setup_name_label()


func _setup_name_label():
	if _name_label:
		_name_label.queue_free()
	_name_label = Label.new()
	_name_label.text = username
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.custom_minimum_size = Vector2(120, 20)
	_name_label.position = Vector2(-60, -50)
	add_child(_name_label)


func _apply_stats_from_slot():
	if slot == 1 and GameData.p1_stats != null:
		stats = GameData.p1_stats
	elif slot == 2 and GameData.p2_stats != null:
		stats = GameData.p2_stats


func _setup_actions():
	if slot == 1:
		_actions = {
			"left":    "p1_left",
			"right":   "p1_right",
			"jump":    "p1_jump",
			"attack":  "p1_attack",
			"down":    "p1_down",
			"special": "p1_special"
		}
	else:
		_actions = {
			"left":    "p2_left",
			"right":   "p2_right",
			"jump":    "p2_jump",
			"attack":  "p2_attack",
			"down":    "p2_down",
			"special": "p2_special"
		}


func _physics_process(delta):
	if stats == null:
		return

	if not is_on_floor():
		velocity.y += gravity * stats.weight * delta

	if is_local_player:
		if not can_special:
			_special_cooldown_timer -= delta
			if _special_cooldown_timer <= 0:
				can_special = true
		_handle_input()
		_push_away_from_others(delta)
	else:
		# Remoto: interpolar hacia posición objetivo
		if _has_remote_target:
			global_position = global_position.lerp(_target_pos, 12.0 * delta)
			velocity.x = _target_vel.x
			if _target_vel.y < -50.0:
				velocity.y = _target_vel.y

	move_and_slide()

	if is_local_player:
		if not _was_on_floor and is_on_floor():
			_play_sfx(stats.sfx_land)
		_was_on_floor = is_on_floor()
		_update_animation()

	_check_out_of_bounds()


func _push_away_from_others(delta: float):
	var others = get_tree().get_nodes_in_group("fighters")
	for other in others:
		if other == self:
			continue
		if not is_instance_valid(other) or not other.visible:
			continue
		var diff   = global_position - other.global_position
		var dist_x = abs(diff.x)
		var dist_y = diff.y
		if dist_x > 80 and abs(dist_y) > 80:
			continue
		if dist_y < 0 and dist_y > -100 and dist_x < 60:
			var slide_dir = sign(diff.x)
			if slide_dir == 0:
				slide_dir = 1.0 if slot == 1 else -1.0
			global_position.x += slide_dir * 120.0 * delta
			velocity.x = slide_dir * stats.move_speed * 1.5
			if is_on_floor():
				velocity.y = stats.jump_force * 0.4
		elif abs(diff.y) < 40 and dist_x < 60:
			var push_dir = sign(diff.x)
			if push_dir == 0:
				push_dir = 1.0 if slot == 1 else -1.0
			global_position.x += push_dir * 80.0 * delta
			velocity.x += push_dir * 250.0 * delta


func _handle_input():
	is_crouching = Input.is_action_pressed(_actions["down"]) and is_on_floor()

	if Input.is_action_just_pressed(_actions["down"]) and is_on_floor():
		set_collision_mask_value(1, false)
		position.y += 8
		await get_tree().create_timer(0.25).timeout
		set_collision_mask_value(1, true)
		return

	var dir = Input.get_axis(_actions["left"], _actions["right"])

	if is_crouching:
		velocity.x = move_toward(velocity.x, 0, stats.move_speed * 0.5)
	elif dir != 0:
		velocity.x = dir * stats.move_speed
		var new_facing: float = 1.0 if dir > 0 else -1.0
		if not stats.faces_right:
			new_facing = -new_facing
		if new_facing != _facing:
			_facing = new_facing
			sprite.scale.x = _facing
	else:
		velocity.x = move_toward(velocity.x, 0, stats.move_speed * 0.2)

	if Input.is_action_just_pressed(_actions["jump"]) and is_on_floor() and not is_crouching:
		velocity.y = stats.jump_force
		_play_sfx(stats.sfx_jump)

	if Input.is_action_just_pressed(_actions["attack"]) and can_attack and not is_crouching:
		_do_attack()

	if Input.is_action_just_pressed(_actions["special"]) and can_special:
		if stats.has_special and stats.projectile_scene:
			_do_special()


func _update_animation():
	if not sprite:
		return
	if (_current_anim == "attack" or _current_anim == "special") and sprite.is_playing():
		return
	var new_anim: String
	if not is_on_floor():
		new_anim = "jump"
	elif is_crouching:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("crouch"):
			new_anim = "crouch"
		else:
			new_anim = "idle"
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
	can_attack    = false
	_current_anim = "attack"
	sprite.play("attack")
	_play_sfx(stats.sfx_attack)

	if GameData.is_online:
		var ws = get_node_or_null("/root/WebSocketClient")
		if ws and ws.is_connected_to_room:
			ws._socket.send_text(JSON.stringify({"type": "attack"}))

	var space         = get_world_2d().direct_space_state
	var query         = PhysicsShapeQueryParameters2D.new()
	var shape         = CircleShape2D.new()
	shape.radius      = 70.0
	var side          = 1 if _facing > 0 else -1
	var attack_offset = Vector2(60 * side, 0)
	query.shape             = shape
	query.transform         = global_transform
	query.transform.origin += attack_offset
	query.collision_mask    = 2

	var results = space.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body != self and body.has_method("take_hit"):
			body.take_hit(stats.attack_damage, global_position)

	await sprite.animation_finished
	_current_anim = ""
	await get_tree().create_timer(stats.attack_cooldown).timeout
	can_attack = true


func _do_special():
	can_special             = false
	_special_cooldown_timer = stats.special_cooldown
	_play_sfx(stats.sfx_special)

	if GameData.is_online:
		var ws = get_node_or_null("/root/WebSocketClient")
		if ws and ws.is_connected_to_room:
			ws._socket.send_text(JSON.stringify({"type": "special"}))

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("special"):
		_current_anim = "special"
		sprite.play("special")

	var projectile = stats.projectile_scene.instantiate()
	get_parent().add_child(projectile)
	var dir = 1.0 if _facing > 0 else -1.0
	projectile.global_position = global_position + Vector2(60 * dir, -10)
	projectile.setup(dir, player_id, stats.special_damage)

	if _current_anim == "special":
		await sprite.animation_finished
		_current_anim = ""


func take_hit(damage: int, source_pos: Vector2):
	damage_percent += damage
	var multiplier  = 1.0 + (damage_percent / 100.0)
	var direction   = (global_position - source_pos).normalized()
	direction.y    -= 0.45
	velocity        = direction.normalized() * stats.knockback_power * multiplier
	_play_sfx(stats.sfx_hit)
	took_damage.emit(player_id, damage_percent)


func apply_remote_state(data: Dictionary):
	match data.get("type", ""):
		"input":
			var px = float(data.get("px", -1.0))
			var py = float(data.get("py", -1.0))
			if px != -1.0:
				_target_pos = Vector2(px, py)
				_target_vel = Vector2(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)))
				_has_remote_target = true

			var input_x = float(data.get("x", 0.0))
			if input_x != 0:
				var new_facing: float = 1.0 if input_x > 0 else -1.0
				if stats and not stats.faces_right:
					new_facing = -new_facing
				if new_facing != _facing:
					_facing = new_facing
					sprite.scale.x = _facing

			if (_current_anim == "attack" or _current_anim == "special") and sprite.is_playing():
				return
			var vx = float(data.get("vx", 0.0))
			var new_anim: String
			if not is_on_floor():
				new_anim = "jump"
			elif abs(vx) > 50:
				new_anim = "run"
			else:
				new_anim = "idle"
			if new_anim != _current_anim:
				_current_anim = new_anim
				sprite.play(new_anim)

		"attack":
			if _current_anim != "attack":
				_current_anim = "attack"
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
					sprite.play("attack")
					await sprite.animation_finished
				_current_anim = ""

		"special":
			if _current_anim != "special":
				_current_anim = "special"
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("special"):
					sprite.play("special")
					await sprite.animation_finished
				_current_anim = ""

		"player_hit":
			pass


func _check_out_of_bounds():
	if position.y > 1000 or abs(position.x) > 1800:
		_die()


func _die():
	stocks -= 1
	died.emit(player_id)
	if stocks > 0:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		_play_sfx(stats.sfx_death)
		await get_tree().create_timer(1.5).timeout
		position                = Vector2(576, 150)
		velocity                = Vector2.ZERO
		damage_percent          = 0.0
		can_attack              = true
		can_special             = true
		_special_cooldown_timer = 0.0
		_facing                 = 1.0 if stats.faces_right else -1.0
		scale.x                 = 1.0
		sprite.scale.x          = _facing
		_target_pos             = Vector2(576, 150)
		_has_remote_target      = false
		took_damage.emit(player_id, 0.0)
		show()
		process_mode  = Node.PROCESS_MODE_INHERIT
		if sprite:
			sprite.play("idle")
		_current_anim = ""
	else:
		_play_sfx(stats.sfx_death)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED


func _play_sfx(stream: AudioStream):
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()
