extends CharacterBody2D
class_name Boss

signal boss_defeated

@export var speed := 40
@export var max_health := 30
@export var stop_distance := 15.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var hit_offset: float = 10.0
@export var points: int = 500
@onready var health_bar: ProgressBar = $HealthBarPivot/HealthBar

var player: Node2D = null
var player_target: Node2D = null
var health: int
var attack_timer: float = 0.0
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var has_dealt_damage: bool = false
var hurt_timer: float = 0.0
var phase2_threshold: float = 0.5
var in_phase2: bool = false
var can_fear_talk := true

const hurt_duration: float = 0.385
const PHASE2_SPEED_BONUS    := 15
const PHASE2_DAMAGE_BONUS   := 8
const PHASE2_COOLDOWN_MULT  := 0.75

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape_up: CollisionShape2D = $Hitbox/CollisionShape2D_Up
@onready var hitbox_shape_down: CollisionShape2D = $Hitbox/CollisionShape2D_Down
@onready var damage_sound: AudioStreamPlayer2D = $DamageSound

func _ready() -> void:
	health = max_health
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
	health = max_health
	
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false
	
	hitbox.damage = attack_damage

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

	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false
			if not is_attacking:
				sprite.play("idle")
		return

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
	if is_dead:
		return
		
	health -= amount

	damage_sound.stop()
	damage_sound.play()
	health_bar.value = health
	health_bar.visible = true
	
	if health < max_health * 0.25 and can_fear_talk:
		can_fear_talk = false

		AIManager.request_dialogue({
			"enemy_type": "vampire",
			"enemy_state": "fear"
		}, self)

		await get_tree().create_timer(4.0).timeout
		can_fear_talk = true
		
	if not in_phase2 and float(health) / float(max_health) <= phase2_threshold:
		_enter_phase2()

	if health <= 0:
		await get_tree().create_timer(0.3).timeout
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
			boss_defeated.emit()
		sprite.play("death")
	else:
		is_attacking = false
		is_hurt = true
		hurt_timer = hurt_duration
		has_dealt_damage = false
		_set_hitboxes(true)
		attack_timer = attack_cooldown
		sprite.frame = 0
		sprite.play("damage")

func attack() -> void:
	is_attacking = true
	sprite.play("attack")

	if randf() < 0.5:  # 50% chance (important to avoid spam)
		AIManager.request_dialogue({
			"enemy_type": "vampire",
			"enemy_state": "taunt"
		}, self)

func _enter_phase2() -> void:
	in_phase2 = true
	speed += PHASE2_SPEED_BONUS
	attack_damage += PHASE2_DAMAGE_BONUS
	attack_cooldown *= PHASE2_COOLDOWN_MULT
	hitbox.damage = attack_damage
	print("Boss entered phase 2!")
	AIManager.request_dialogue({
	"enemy_type": "vampire",
	"enemy_state": "taunt"
}, self)

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
			if not is_hurt:
				is_attacking = false
				has_dealt_damage = false
				_set_hitboxes(true)
				attack_timer = attack_cooldown
				sprite.play("idle")
		"damage":
			pass
		"death":
			queue_free()

func setup(config: Dictionary) -> void:
	if config.has("speed"): speed = config["speed"]
	if config.has("max_health"): max_health = config["max_health"]
	if config.has("attack_damage"): attack_damage = config["attack_damage"]
	if config.has("attack_cooldown"): attack_cooldown = config["attack_cooldown"]
	if config.has("hit_offset"): hit_offset = config["hit_offset"]
	if config.has("point_value"): points = config["point_value"]
	if config.has("phase2_threshold"): phase2_threshold = config["phase2_threshold"]
	health = max_health
