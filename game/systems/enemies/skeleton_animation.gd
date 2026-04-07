extends CharacterBody2D

@export var speed := 40
@export var max_health := 3
@export var stop_distance := 15.0

var health := max_health
var player: Node2D = null
var player_target: Node2D = null

@onready var sprite = $AnimatedSprite2D
@onready var nav_agent = $NavigationAgent2D

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = stop_distance
	await get_tree().process_frame
	_find_player()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		player_target = player.get_node_or_null("EnemyTarget")
		if not player_target:
			player_target = player

func _physics_process(_delta: float) -> void:
	if player == null:
		_find_player()
		return

	nav_agent.target_position = player_target.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		velocity = (next_pos - global_position).normalized() * speed
		move_and_slide()

	sprite.play("movement" if velocity != Vector2.ZERO else "idle")

	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
		
func take_damage(amount: int) -> void:
	health -= amount
	sprite.play("death" if health <= 0 else "damage")

func attack() -> void:
	sprite.play("attack")

func _on_animation_finished() -> void:
	match sprite.animation:
		"damage": sprite.play("idle")
		"death": queue_free()
