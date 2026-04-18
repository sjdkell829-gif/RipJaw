extends CharacterBody2D

@export var stats: FighterStats
@export var player_id: int = 2
@export var is_local_player: bool = false

var slot: int = 2

var damage_percent: float = 0.0
var stocks: int = 3
var can_attack: bool = true
var is_crouching: bool = false
var _was_on_floor: bool = true
var _facing: float = 1.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

signal took_damage(pid, percent)
signal died(pid)

var _actions: Dictionary = {}
var _current_anim: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer = $AudioStreamPlayer

var _target: CharacterBody2D = null
var _think_timer: float = 0.0
var _think_interval: float = 0.15
var _jump_cooldown: float = 0.0
var _retreat_timer: float = 0.0

@export var difficulty: int = 1


func _ready():
	difficulty = clamp(difficulty, 0, 2)
	_apply_stats_from_slot()
	if stats == null:
		push_error("AI Fighter no tiene FighterStats asignado")
		return
	_setup_actions()
	_facing = 1.0 if stats.faces_right else -1.0
	scale.x = 1.0
	sprite.scale.x = _facing
	await get_tree().process_frame
	_find_target()
	if sprite:
		sprite.play("idle")


func setup(pid: int, local: bool, p_slot: int = 2):
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


func _apply_stats_from_slot():
	if slot == 1 and GameData.p1_stats != null:
		stats = GameData.p1_stats
	elif slot == 2 and GameData.p2_stats != null:
		stats = GameData.p2_stats


func _setup_actions():
	if slot == 1:
		_actions = {"left": "p1_left", "right": "p1_right", "jump": "p1_jump", "attack": "p1_attack", "down": "p1_down", "special": "p1_special"}
	else:
		_actions = {"left": "p2_left", "right": "p2_right", "jump": "p2_jump", "attack": "p2_attack", "down": "p2_down", "special": "p2_special"}


func _physics_process(delta):
	if stats == null:
		return

	if not is_on_floor():
		velocity.y += gravity * stats.weight * delta

	if is_local_player:
		_think_timer   -= delta
		_jump_cooldown -= delta
		_retreat_timer -= delta

		if _think_timer <= 0:
			_think_timer = _think_interval
			_ai_think()

		_push_away_from_others(delta)

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


func _find_target():
	var players = get_tree().get_nodes_in_group("fighters")
	for p in players:
		if p != self:
			_target = p
			return
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child != self and child.has_method("take_hit"):
				_target = child
				return


func _ai_think():
	if _target == null or not is_instance_valid(_target):
		_find_target()
		return
	if not _target.visible:
		velocity.x = move_toward(velocity.x, 0, 20)
		return

	var dist         = global_position.distance_to(_target.global_position)
	var dir_to       = sign(_target.global_position.x - global_position.x)
	var attack_range = 120.0

	var new_facing: float = 1.0 if dir_to > 0 else -1.0
	if not stats.faces_right:
		new_facing = -new_facing
	if new_facing != _facing:
		_facing = new_facing
		sprite.scale.x = _facing

	if is_on_floor() and _target.global_position.y > global_position.y + 80:
		if randf() < 0.3:
			set_collision_mask_value(1, false)
			position.y += 8
			await get_tree().create_timer(0.25).timeout
			set_collision_mask_value(1, true)
			return

	match difficulty:
		0: _ai_easy(dist, dir_to, attack_range)
		1: _ai_normal(dist, dir_to, attack_range)
		2: _ai_hard(dist, dir_to, attack_range)


func _ai_easy(dist: float, dir_to: int, attack_range: float):
	if dist > attack_range:
		velocity.x = dir_to * stats.move_speed * 0.5
	else:
		velocity.x = 0
		if can_attack and randf() > 0.7:
			_do_attack()
	if is_on_floor() and _jump_cooldown <= 0 and randf() > 0.95:
		velocity.y = stats.jump_force
		_jump_cooldown = 2.0


func _ai_normal(dist: float, dir_to: int, attack_range: float):
	if _retreat_timer > 0:
		velocity.x = -dir_to * stats.move_speed * 0.6
		return
	if dist > attack_range * 1.5:
		velocity.x = dir_to * stats.move_speed * 0.8
	elif dist <= attack_range:
		velocity.x = dir_to * stats.move_speed * 0.3
		if can_attack:
			_do_attack()
		if randf() > 0.7:
			_retreat_timer = 0.5
	else:
		velocity.x = dir_to * stats.move_speed * 0.5
	if is_on_floor() and _jump_cooldown <= 0:
		var height_diff = global_position.y - _target.global_position.y
		if height_diff > 80 or (dist < 60 and randf() > 0.85):
			velocity.y = stats.jump_force
			_jump_cooldown = 1.5


func _ai_hard(dist: float, dir_to: int, attack_range: float):
	if _retreat_timer > 0:
		velocity.x = -dir_to * stats.move_speed
		return
	if dist > attack_range:
		velocity.x = dir_to * stats.move_speed
	else:
		if can_attack:
			_do_attack()
		velocity.x = dir_to * stats.move_speed * 0.4
		if randf() > 0.8:
			_retreat_timer = 0.3
	if is_on_floor() and _jump_cooldown <= 0:
		var height_diff = global_position.y - _target.global_position.y
		if height_diff > 60 or randf() > 0.92:
			velocity.y = stats.jump_force
			_jump_cooldown = 1.0


func _update_animation():
	if not sprite:
		return
	if _current_anim == "attack" and sprite.is_playing():
		return
	var new_anim: String
	if not is_on_floor():
		new_anim = "jump"
	elif abs(velocity.x) > 50:
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

	if _target and is_instance_valid(_target) and _target.visible:
		var dist = global_position.distance_to(_target.global_position)
		if dist < 130.0:
			_target.take_hit(stats.attack_damage, global_position)

	await sprite.animation_finished
	_current_anim = ""
	await get_tree().create_timer(stats.attack_cooldown).timeout
	can_attack = true


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
			if px != -1.0:
				global_position.x = lerp(global_position.x, px, 0.4)
			velocity.x = float(data.get("vx", 0.0))
			var remote_vy = float(data.get("vy", 0.0))
			if not is_on_floor() or remote_vy < -100.0:
				velocity.y = remote_vy
			var input_x = float(data.get("x", 0.0))
			if input_x != 0:
				var new_facing: float = 1.0 if input_x > 0 else -1.0
				if stats and not stats.faces_right:
					new_facing = -new_facing
				if new_facing != _facing:
					_facing = new_facing
					sprite.scale.x = _facing
			if _current_anim == "attack" and sprite.is_playing():
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
		position       = Vector2(900, 150)
		velocity       = Vector2.ZERO
		damage_percent = 0.0
		can_attack     = true
		_current_anim  = ""
		_facing        = 1.0 if stats.faces_right else -1.0
		scale.x        = 1.0
		sprite.scale.x = _facing
		_find_target()
		took_damage.emit(player_id, 0.0)
		show()
		process_mode = Node.PROCESS_MODE_INHERIT
		if sprite:
			sprite.play("idle")
	else:
		_play_sfx(stats.sfx_death)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED


func _play_sfx(stream: AudioStream):
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()
