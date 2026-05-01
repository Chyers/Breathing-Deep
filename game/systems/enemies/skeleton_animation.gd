extends CharacterBody2D

# Exports

@export var speed: int = 40
@export var max_health: int = 30
@export var stop_distance: float = 15.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var hit_offset: float = 10.0
@export var points: int = 10
@export var drop_table: Array[PackedScene] = []
@export var drop_chance: float = 0.5

# Constants

const HURT_DURATION: float = 0.385
const IFRAMES_DURATION: float = 1.0
const POST_HURT_DURATION: float = 0.4
const KNOCKBACK_SPEED: float = 80.0
const KNOCKBACK_DECEL: float = 300.0
const POST_HURT_SPEED_MULT: float = 1.5
const SEPARATION_RADIUS: float = 40.0
const SEPARATION_WEIGHT: float = 0.8
const DROP_JITTER: float = 6.0

# State

var health: int
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var iframes_timer: float = 0.0
var post_hurt_timer: float = 0.0

var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var has_dealt_damage: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var _target_jitter: Vector2 = Vector2.ZERO

var player: Node2D = null
var player_target: Node2D = null

# Node refs

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape_up: CollisionShape2D = $Hitbox/CollisionShape2D_Up
@onready var hitbox_shape_down: CollisionShape2D = $Hitbox/CollisionShape2D_Down
@onready var health_bar: ProgressBar = $HealthBarPivot/HealthBar
@onready var damage_sound: AudioStreamPlayer2D = $DamageSound

# Lifecycle

func _ready() -> void:
	health = max_health

	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false

	hitbox.damage = attack_damage
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle")

	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = stop_distance
	_set_hitboxes(true)

	await get_tree().process_frame
	_find_player()
	_randomise_jitter()

func _physics_process(delta: float) -> void:
	_tick_iframes(delta)

	if player == null:
		_find_player()
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	if _tick_hurt(delta):
		return
	if _tick_post_hurt(delta):
		return
	if is_attacking:
		velocity = Vector2.ZERO
		return

	_chase_and_attack()

# Initialisation helpers

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	player = players[0]
	player_target = player.get_node_or_null("EnemyTarget") if player else player

func _randomise_jitter() -> void:
	var angle := randf() * TAU
	var radius := randf_range(0.0, stop_distance * 0.5)
	_target_jitter = Vector2(cos(angle), sin(angle)) * radius

# Per-frame state ticks

func _tick_iframes(delta: float) -> void:
	if iframes_timer > 0.0:
		iframes_timer -= delta

func _tick_hurt(delta: float) -> bool:
	if hurt_timer <= 0.0:
		return false

	hurt_timer -= delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECEL * delta)
	global_position += knockback_velocity * delta

	if hurt_timer <= 0.0:
		is_hurt = false
		post_hurt_timer = POST_HURT_DURATION
		knockback_velocity = Vector2.ZERO
		if not is_attacking:
			sprite.play("idle")

	return true

func _tick_post_hurt(delta: float) -> bool:
	if post_hurt_timer <= 0.0:
		return false

	post_hurt_timer -= delta
	var away := (global_position - player_target.global_position).normalized()
	global_position += away * speed * POST_HURT_SPEED_MULT * delta

	if post_hurt_timer <= 0.0:
		set_collision_layer_value(3, true)

	return true

# Movement & combat

func _chase_and_attack() -> void:
	var jittered_target := player_target.global_position + _target_jitter
	nav_agent.target_position = jittered_target

	if global_position.distance_to(jittered_target) <= stop_distance:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			attack()
		return

	if not nav_agent.is_navigation_finished():
		var nav_dir := (nav_agent.get_next_path_position() - global_position).normalized()
		var sep_dir := _get_separation_force().normalized()
		velocity = (nav_dir + sep_dir * SEPARATION_WEIGHT).normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	_update_facing()
	sprite.play("movement" if velocity != Vector2.ZERO else "idle")

func _on_player_detected():
	taunt_player()
	
func taunt_player():
	AIManager.request_dialogue({
		"type": "enemy",
		"enemy_type": "skeleton",
		"enemy_state": "taunt",
		"player_health": player.health
	}, self)

func _get_separation_force() -> Vector2:
	var separation := Vector2.ZERO
	for neighbor in get_tree().get_nodes_in_group("enemy"):
		if neighbor == self:
			continue
		var offset: Vector2 = global_position - neighbor.global_position
		var dist := offset.length()
		if dist < SEPARATION_RADIUS and dist > 0.0:
			separation += offset.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return separation

func _update_facing() -> void:
	var dir := player_target.global_position - global_position
	var vertical : bool = abs(dir.y) > abs(dir.x)

	sprite.flip_h = false if vertical else dir.x < 0
	hitbox.position.x = 0.0 if vertical else (-hit_offset if dir.x < 0 else hit_offset)
	hitbox.position.y = (-hit_offset if dir.y < 0 else hit_offset) if vertical else 0.0

func attack() -> void:
	is_attacking = true
	sprite.play("attack")
	taunt_player()

# Damage & death

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead or iframes_timer > 0.0:
		return

	iframes_timer = IFRAMES_DURATION
	health -= amount
	_refresh_health_bar()
	_play_damage_sound()

	if health <= 0:
		await _die()
	else:
		_enter_hurt_state(source_position)

func _enter_hurt_state(source_position: Vector2) -> void:
	set_collision_layer_value(3, false)
	is_attacking = false
	is_hurt = true
	hurt_timer = HURT_DURATION
	has_dealt_damage = false
	attack_timer = attack_cooldown
	_set_hitboxes(true)
	sprite.frame = 0
	sprite.play("damage")

	if source_position != Vector2.ZERO:
		knockback_velocity = (global_position - source_position).normalized() * KNOCKBACK_SPEED

func _die() -> void:
	await get_tree().create_timer(0.3).timeout
	is_dead = true
	is_attacking = false
	is_hurt = false
	hurt_timer = 0.0
	_disable_collisions()
	health_bar.visible = false
	_set_hitboxes(true)
	set_physics_process(false)
	ScoreManager.add_score(points)
	sprite.play("death")

# Hitbox helpers

func _set_hitboxes(disabled: bool) -> void:
	hitbox_shape.disabled = disabled
	hitbox_shape_up.disabled = disabled
	hitbox_shape_down.disabled = disabled

func _disable_collisions() -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	for area in [$Hitbox, $Hurtbox]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

# UI helpers

func _refresh_health_bar() -> void:
	health_bar.value = health
	health_bar.visible = true
	
	if health < 20:
		AIManager.request_dialogue({
			"enemy_type": "skeleton",
			"enemy_state": "fear"
		}, self)
	
	if health <= 0:
		await get_tree().create_timer(0.3).timeout
		_disable_collisions()
		health_bar.visible = false
		is_dead = true
		is_attacking = false
		is_hurt = false
		hurt_timer = 0.0
		_set_hitboxes(true)
		set_physics_process(false)
		ScoreManager.add_score(points)
		var hurtbox = get_node_or_null("Hurtbox")
		if hurtbox:
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
		sprite.play("death")
	else:
		is_attacking = false
		is_hurt = true
		hurt_timer = HURT_DURATION
		has_dealt_damage = false
		_set_hitboxes(true)
		attack_timer = attack_cooldown
		sprite.frame = 0
		sprite.play("damage")

func _play_damage_sound() -> void:
	damage_sound.stop()
	damage_sound.play()

# ─── Signal handlers ────────────────────────────────────────────────────────

func _on_frame_changed() -> void:
	if sprite.animation != "attack":
		return
	var halfway: int = sprite.sprite_frames.get_frame_count("attack") / 2
	if sprite.frame == halfway and not has_dealt_damage:
		has_dealt_damage = true
		_set_hitboxes(false)
	elif sprite.frame == halfway + 1:
		_set_hitboxes(true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	var parent := area.get_parent()
	if parent.has_method("take_damage"):
		parent.take_damage(attack_damage)

func _on_animation_finished() -> void:
	match sprite.animation:
		"attack":
			if not is_hurt:
				is_attacking = false
				has_dealt_damage = false
				attack_timer = attack_cooldown
				_set_hitboxes(true)
				sprite.play("idle")
		"death":
			_drop_item()
			queue_free()

# ─── Drops ──────────────────────────────────────────────────────────────────

func _drop_item() -> void:
	if drop_table.is_empty() or randf() > drop_chance:
		return
	var item : Node = drop_table.pick_random().instantiate()
	get_parent().add_child(item)
	item.global_position = global_position + Vector2(
		randf_range(-DROP_JITTER, DROP_JITTER),
		randf_range(-DROP_JITTER, DROP_JITTER)
	)

# ─── Setup (external config) ─────────────────────────────────────────────────

func setup(config: Dictionary) -> void:
	if config.has("speed"):speed = config["speed"]
	if config.has("max_health"): max_health = config["max_health"]
	if config.has("attack_damage"):attack_damage = config["attack_damage"]
	if config.has("attack_cooldown"):attack_cooldown = config["attack_cooldown"]
	if config.has("hit_offset"): hit_offset = config["hit_offset"]
	if config.has("points"): points = config["points"]
	health = max_health  # re-syncs health after stat changes
