extends CharacterBody2D

@export var speed := 40
@export var max_health := 3
@export var stop_distance := 15.0
@export var attack_damage : int = 10
@export var attack_cooldown: float = 1.2

var health := max_health
var player: Node2D = null
var player_target: Node2D = null
var is_attacking: bool = false
var attack_timer: float = 0.0
var has_dealt_damage: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var nav_agent = $NavigationAgent2D

@onready var hitbox = $Hitbox
@onready var hitbox_shape = $Hitbox/CollisionShape2D

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.play("idle")
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = stop_distance
	hitbox_shape.disabled = true

	await get_tree().process_frame
	_find_player()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player_target = player.get_node_or_null("EnemyTarget")
		if not player_target:
			player_target = player

func _physics_process(delta: float) -> void:
	if player == null:
		_find_player()
		return
	if attack_timer > 0:
		attack_timer -= delta
	if is_attacking:
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
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		velocity = (next_pos - global_position).normalized() * speed
		move_and_slide()
	var dir_to_player := player_target.global_position - global_position
	if dir_to_player.x != 0:
		sprite.flip_h = dir_to_player.x < 0
		hitbox.position.x = -abs(hitbox.position.x) if dir_to_player.x < 0 else abs(hitbox.position.x)

	sprite.play("movement" if velocity != Vector2.ZERO else "idle")

func take_damage(amount: int) -> void:
	health -= amount
	sprite.play("death" if health <= 0 else "damage")

func attack() -> void:
	is_attacking = true
	sprite.play("attack")

func _on_frame_changed() -> void:
	if sprite.animation != "attack":
		return

	var halfway_frame: int = sprite.sprite_frames.get_frame_count("attack") / 2

	if sprite.frame == halfway_frame and not has_dealt_damage:
		has_dealt_damage = true
		hitbox_shape.disabled = false

	elif sprite.frame == halfway_frame + 1:
		hitbox_shape.disabled = true

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "Hurtbox" and player != null:
		player.take_damage(attack_damage)

func _on_animation_finished() -> void:
	match sprite.animation:
		"attack":
			is_attacking = false
			has_dealt_damage = false
			hitbox_shape.disabled = true
			attack_timer = attack_cooldown
			sprite.play("idle")
		"damage":
			sprite.play("idle")
		"death":
			queue_free()
