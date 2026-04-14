extends Area2D

@export var buff_value: int = 25
@export var item_icon: Texture2D = null

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var item = Item.new()
		item.item_name = "Buff"
		item.icon = item_icon
		if body.has_method("add_item"):
			body.add_item(item)
		queue_free()
