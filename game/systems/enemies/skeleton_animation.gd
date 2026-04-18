extends CharacterBody2D

@export var speed := 40
@export var max_health := 30
@export var stop_distance := 15.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var hit_offset: float = 10.0

var player: Node2D = null
var player_target: Node2D = null
var health: int
var attack_timer: float = 0.0
var is_attacking: bool = false
var is_hurt: bool = false
var has_dealt_damage: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape_up: CollisionShape2D = $Hitbox/CollisionShape2D_Up
@onready var hitbox_shape_down: CollisionShape2D = $Hitbox/CollisionShape2D_Down

func _ready() -> void:
	health = max_health  # fixes the one-hit bug from earlier
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

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player_target = player.get_node_or_null("EnemyTarget")
		if not player_target:
			player_target = player

func _physics_process(delta: float) -> void:
	if player == null:
		_find_player()
		return

	attack_timer = max(attack_timer - delta, 0.0)

	if is_attacking or is_hurt:
		velocity = Vector2.ZERO
		return

	nav_agent.target_position = player_target.global_position
	var dist := global_position.distance_to(player_target.global_position)

	if dist <= stop_distance:
		velocity = Vector2.ZERO
		if attack_timer <= 0:
			attack()
			return
	elif nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		velocity = (nav_agent.get_next_path_position() - global_position).normalized() * speed
		move_and_slide()

	_update_facing()
	sprite.play("movement" if velocity != Vector2.ZERO else "idle")

func _update_facing() -> void:
	var dir_to_player := player_target.global_position - global_position
	if abs(dir_to_player.y) > abs(dir_to_player.x):
		sprite.flip_h = false
		hitbox.position.x = 0
		hitbox.position.y = -hit_offset if dir_to_player.y < 0 else hit_offset
	else:
		sprite.flip_h = dir_to_player.x < 0
		hitbox.position.y = 0
		hitbox.position.x = -hit_offset if dir_to_player.x < 0 else hit_offset

func _set_hitboxes(disabled: bool) -> void:
	hitbox_shape.disabled = disabled
	hitbox_shape_up.disabled = disabled
	hitbox_shape_down.disabled = disabled

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_set_hitboxes(true)  # ensure hitboxes off on death
		sprite.play("death")
	else:
		is_attacking = false
		is_hurt = true
		has_dealt_damage = false
		_set_hitboxes(true)
		attack_timer = attack_cooldown
		sprite.play("damage")

func attack() -> void:
	is_attacking = true
	sprite.play("attack")

func _on_frame_changed() -> void:
	if sprite.animation != "attack":
		return
	var halfway_frame: int = sprite.sprite_frames.get_frame_count("attack") / 2
	if sprite.frame == halfway_frame and not has_dealt_damage:
		has_dealt_damage = true
		_set_hitboxes(false)
	elif sprite.frame == halfway_frame + 1:
		_set_hitboxes(true)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			parent.take_damage(attack_damage)

func _on_animation_finished() -> void:
	match sprite.animation:
		"attack":
			is_attacking = false
			has_dealt_damage = false
			_set_hitboxes(true)
			attack_timer = attack_cooldown
			sprite.play("idle")
		"damage":
			is_hurt = false
			sprite.play("idle")
		"death":
			queue_free()
