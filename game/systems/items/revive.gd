extends Area2D
 
func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
 
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("add_item"):
		return
 
	var revival_item := Item.new()
	revival_item.item_name = "Revival Orb"
	revival_item.item_type = Item.Type.REVIVE
	revival_item.max_stack = 1
	revival_item.quantity = 1
	revival_item.icon = $Sprite2D.texture   # grab texture directly
 
	body.add_item(revival_item)
	queue_free()
