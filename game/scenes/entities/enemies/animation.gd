extends CharacterBody2D

const SPEED = 60.0
const GRAVITY = 980.0

var health = 100
var player = null

@onready var detection_area = $Area2D

func _ready():
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	# Gravity only - no jumping
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player:
		_chase_player()
	else:
		velocity.x = 0

	move_and_slide()

func _chase_player():
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * SPEED  # Only moves horizontally

func take_damage(amount):
	health -= amount
	if health <= 0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_body_exited(body):
	if body.is_in_group("player"):
		player = null
