extends Area2D

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var key_item := Item.new()
		key_item.item_name = "Key"
		key_item.item_type = Item.Type.KEY
		key_item.quantity = 1
		key_item.max_stack = 3
		var sprite: AnimatedSprite2D = $AnimatedSprite2D
		key_item.icon = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		if body.has_method("add_item"):
			body.add_item(key_item)
		queue_free()
