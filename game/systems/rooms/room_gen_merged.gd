extends Node2D

@export var min_items: int = 1
@export var max_items: int = 4

var item_scenes = [
	preload("res://scenes/environment/coin.tscn"),
	preload("res://scenes/environment/health.tscn"),
	preload("res://scenes/environment/buff.tscn")
]

# Expected door node structure per room .tscn:
# Doors/
#   North/   <- CollisionShape or Area2D trigger + SpawnPoint
#   South/
#   East/
#   West/
func _ready() -> void:
	randomize()
	spawn_items()
	# Doors are hidden by default in the .tscn;
	# setup_doors() will enable the correct ones.
	_hide_all_doors()

func _hide_all_doors() -> void:
	var doors_node = get_node_or_null("Doors")
	if not doors_node:
		return
	for door in doors_node.get_children():
		door.visible = false
		# Also disable collision so player can't pass through closed doors
		var col = door.get_node_or_null("CollisionShape2D")
		if col:
			col.disabled = true

# Called by main_scene.gd after instantiation
func setup_doors(active_directions: Array[String]) -> void:
	var doors_node = get_node_or_null("Doors")
	if not doors_node:
		push_warning("Room has no Doors node: " + name)
		return
	for dir in active_directions:
		# Match node name case-insensitively (North, north, NORTH all work)
		var door_node: Node = null
		for child in doors_node.get_children():
			if child.name.to_lower() == dir.to_lower():
				door_node = child
				break
		if door_node:
			door_node.visible = true
			var col = door_node.get_node_or_null("CollisionShape2D")
			if col:
				col.disabled = false
		else:
			print("WARNING: No door node found for direction: ", dir, " in room ", name)

func spawn_items() -> void:
	var spawn_points = $ItemSpawn.get_children()
	var item_count = randi_range(min_items, max_items)
	spawn_points.shuffle()
	for i in range(min(item_count, spawn_points.size())):
		var item = item_scenes.pick_random().instantiate()
		item.position = spawn_points[i].position
		add_child(item)
