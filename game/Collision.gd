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
		
