extends Area2D

@export var coin_value: int = 1

func _ready() -> void:
	# Connect the signal to a method on this node
	connect("body_entered", Callable(self, "_on_body_entered"))

# Function called when a PhysicsBody2D enters the area
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# Handle coin value
		if body.has_method("add_coins"):
			body.add_coins(coin_value)

		# Create an Item and add it to player inventory
		var item = Item.new()
		item.name = "Coin"
		var sprite = $AnimatedSprite2D
		item.icon = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)

		if body.has_method("add_item"):
			body.add_item(item)

		queue_free()
