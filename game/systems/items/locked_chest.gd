class_name KeyedChest
extends StaticBody2D

@export var coin_scene: PackedScene
@export var health_potion_scene: PackedScene
@export var buff_potion_scene: PackedScene
@export var revival_orb_scene: PackedScene

const ITEM_POOL = [
	Item.Type.COIN, Item.Type.COIN,
	Item.Type.HEALTH, Item.Type.BUFF, Item.Type.REVIVE
]
const COIN_PROFIT_MULT: float = 1.5
const DROP_JITTER: float = 24.0

var held_type: Item.Type
var held_quantity: int
var is_opening: bool = false
var is_locked: bool = true

func _ready() -> void:
	_generate_contents()
	$AnimatedSprite2D.play("idle")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

func _generate_contents() -> void:
	held_type = ITEM_POOL[randi() % ITEM_POOL.size()]
	held_quantity = randi_range(1, 10)

# Called when the player's hitbox overlaps the chest (same as normal Chest).
func take_hit(player: Node) -> void:
	if is_opening:
		return

	if is_locked:
		# Check the player actually has a key in inventory
		var key_index := _find_key_in_inventory(player)
		if key_index == -1:
			print("KeyedChest: no key!")
			return
		# Consume the key
		var key_item: Item = player.inventory[key_index]
		key_item.quantity -= 1
		if key_item.quantity <= 0:
			player.inventory.remove_at(key_index)
		player.update_inventory_ui()
		is_locked = false

	is_opening = true
	$AnimatedSprite2D.play("open")

func _find_key_in_inventory(player: Node) -> int:
	for i in player.inventory.size():
		if player.inventory[i].item_type == Item.Type.KEY:
			return i
	return -1

func _on_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "open":
		_drop_items()
		queue_free()

func _drop_items() -> void:
	for i in 10:
		var drop := coin_scene.instantiate()
		get_parent().add_child(drop)
		drop.global_position = global_position + Vector2(
			randf_range(-DROP_JITTER, DROP_JITTER),
			randf_range(-DROP_JITTER, DROP_JITTER)
		)
		if drop.has_method("set_coin_value"):
			drop.coin_value = 1

	var other_scenes := [health_potion_scene, buff_potion_scene, revival_orb_scene]
	for scene in other_scenes:
		if scene == null:
			continue
		for i in 2:
			var drop : Node = scene.instantiate()
			get_parent().add_child(drop)
			drop.global_position = global_position + Vector2(
				randf_range(-DROP_JITTER, DROP_JITTER),
				randf_range(-DROP_JITTER, DROP_JITTER)
			)
