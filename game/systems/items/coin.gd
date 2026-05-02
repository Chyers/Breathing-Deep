extends Area2D

@export var coin_value: int = 1

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_coins"):
			var sprite: AnimatedSprite2D = $AnimatedSprite2D
			var icon: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
			body.add_coins(coin_value, icon)
		queue_free()
