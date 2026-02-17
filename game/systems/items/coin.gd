extends Area2D

@export var coin_value: int = 1

func _ready() -> void:
	# Connect the signal to a method on this node
	connect("body_entered", Callable(self, "_on_body_entered"))

# Function called when a PhysicsBody2D enters the area
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# Add coins to the player
		if body.has_method("add_coins"):
			body.add_coins(coin_value)
		# Remove this coin
		queue_free()
