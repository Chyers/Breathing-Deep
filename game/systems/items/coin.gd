extends Area2D

@export var coin_value: int = 1

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_coins"):
			body.add_coins(coin_value)

		var item = Item.new()
		item.item_name = "Coin"
		var sprite = $AnimatedSprite2D
		item.icon = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)

		if body.has_method("add_item"):
			body.add_item(item)

		queue_free()
