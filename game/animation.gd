extends CharacterBody2D

const SPEED = 60.0
const GRAVITY = 980.0
const ATTACK_DAMAGE = 10

var player = null
var is_alive = true
var is_attacking = false
var health = 100

@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $Area2D

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	if not is_alive:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player and not is_attacking:
		_chase_player()
	else:
		velocity.x = 0
		animated_sprite.play("idle")

	move_and_slide()

func _chase_player():
	var direction = (player.global_position - global_position).normalized()

	# Flip sprite to face player
	if direction.x > 0:
		animated_sprite.flip_h = false
	elif direction.x < 0:
		animated_sprite.flip_h = true

	# Move towards player
	velocity.x = direction.x * SPEED
	animated_sprite.play("movement")

	# Attack if close enough
	if global_position.distance_to(player.global_position) < 40:
		_start_attack()

func _start_attack():
	if not is_attacking:
		is_attacking = true
		velocity.x = 0
		animated_sprite.play("attack")

func take_damage(amount):
	if not is_alive:
		return
	health -= amount
	if health <= 0:
		_die()
	else:
		animated_sprite.play("damage")

func _die():
	is_alive = false
	velocity = Vector2.ZERO
	animated_sprite.play("death")

func _on_animation_finished():
	match animated_sprite.animation:
		"attack":
			is_attacking = false
		"damage":
			animated_sprite.play("idle")
		"death":
			queue_free()  # Remove enemy from scene

func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_body_exited(body):
	if body.is_in_group("player"):
		player = null
		
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(ATTACK_DAMAGE)
