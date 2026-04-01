var health = 100



func take_damage(amount):
	health -= amount
	print("Player health: ", health)
	if health <= 0:
		queue_free()  
		
func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body
		body.take_damage(10)
		
const CHASE_RANGE = 200.0    
const ATTACK_RANGE = 40.0    
const STOP_RANGE = 30.0      

func _chase_player():
	var distance = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()

	if distance > CHASE_RANGE:
		# Player too far - stop chasing
		velocity.x = 0
	elif distance <= ATTACK_RANGE:
		# Close enough - stop and attack
		velocity.x = 0
		_start_attack()
	elif distance > STOP_RANGE:
		# Chase the player
		velocity.x = direction.x * SPEED
