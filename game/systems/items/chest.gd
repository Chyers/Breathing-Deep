class_name Chest
extends StaticBody2D

# Assigns each existing item scenes in the Inspector
@export var coin_scene: PackedScene
@export var health_potion_scene: PackedScene
@export var buff_potion_scene: PackedScene

const ITEM_POOL = [
	Item.Type.COIN,
	Item.Type.COIN,
	Item.Type.COIN,
	Item.Type.HEALTH,
	Item.Type.BUFF,
]

const COIN_PROFIT_MULT: float = 1.5

var held_type: Item.Type
var held_quantity: int
var price: int = 0
var is_opening: bool = false

func _ready() -> void:
	_generate_contents()
	_calculate_price()
	$AnimatedSprite2D.play("idle")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$Label.text = "%dG" % price
	call_deferred("_setup_label")

func _setup_label() -> void:
	var node = get_parent()
	
	if _is_in_shop_room():
		$Label.show()
	else:
		$Label.hide()

func _generate_contents() -> void:
	held_type = ITEM_POOL[randi() % ITEM_POOL.size()]
	held_quantity = randi_range(1, 10)

func _calculate_price() -> void:
	match held_type:
		Item.Type.COIN:
			price = int(held_quantity / COIN_PROFIT_MULT)
		Item.Type.HEALTH:
			price = held_quantity * 3
		Item.Type.BUFF:
			price = held_quantity * 4
	price = clamp(price, 1, 15)

func _update_price_label() -> void:
	$Label.text = "%d G" % price

func _is_in_shop_room() -> bool:
	# Walks up the tree until we find a node in the shop_room group
	var node = get_parent()
	while node != null:
		if node.is_in_group("shop_room"):
			return true
		node = node.get_parent()
	return false

func take_hit(player: Node) -> void:
	if is_opening:
		return
	if player.has_method("spend_coins") and not player.spend_coins(price):
		print("Not enough coins!")
		return
	is_opening = true
	$Label.hide()
	$AnimatedSprite2D.play("open")

func _on_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "open":
		_drop_items()
		queue_free()

func _drop_items() -> void:
	# Picks the right scene for the held type
	var scene_to_spawn: PackedScene
	match held_type:
		Item.Type.COIN:
			scene_to_spawn = coin_scene
		Item.Type.HEALTH:
			scene_to_spawn = health_potion_scene
		Item.Type.BUFF:
			scene_to_spawn = buff_potion_scene

	for i in held_quantity:
		var drop = scene_to_spawn.instantiate()
		get_parent().add_child(drop)
		# Scatters each item slightly so they don't all stack on one spot
		drop.global_position = global_position + Vector2(
			randf_range(-24, 24),
			randf_range(-24, 24)
		)

		if held_type == Item.Type.COIN and drop.has_method("set_coin_value"):
			drop.coin_value = 1
