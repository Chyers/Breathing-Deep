extends Area2D

@export var buff_value: int = 50

func _ready() -> void:
	# Connect the signal to a method on this node
	connect("body_entered", Callable(self, "_on_body_entered"))

# Function called when a PhysicsBody2D enters the area
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# Add buff to the player
		if body.has_method("add_buff"):
			body.add_buff(buff_value)
		# Remove the flask
		queue_free()
