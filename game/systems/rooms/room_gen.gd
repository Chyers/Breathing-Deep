extends Node2D

@export var min_items: int = 1
@export var max_items: int = 4

var item_scenes = [
	preload("res://scenes/environment/coin.tscn"),
	preload("res://scenes/environment/health.tscn"),
	preload("res://scenes/environment/buff.tscn")
]

const DOOR_SCENES = {
	"north": preload("res://scenes/environment/door/door_north.tscn"),
	"south": preload("res://scenes/environment/door/door_south.tscn"),
	"east":  preload("res://scenes/environment/door/door_east.tscn"),
	"west":  preload("res://scenes/environment/door/door_west.tscn")
}

func _ready() -> void:
	randomize()
	if not is_in_group("boss_room"):
		spawn_items()
	# setup_doors() is called externally by main_scene.gd

# Called by main_scene.gd after instantiation
func setup_doors(active_directions: Array[String]) -> void:
	var doors_node = get_node_or_null("Doors")
	if not doors_node:
		push_warning("Room has no Doors node: " + name)
		return

	# Clear any leftover doors from a previous load (safety net)
	for child in doors_node.get_children():
		child.queue_free()

	for dir in active_directions:
		if not DOOR_SCENES.has(dir):
			push_warning("No door scene registered for direction: " + dir)
			continue

		# Find the marker that tells us where to place this door
		var marker = get_node_or_null("DoorMarkers/" + dir.capitalize())
		if not marker:
			push_warning("No DoorMarker found for direction: " + dir + " in room " + name)
			continue

		var door = DOOR_SCENES[dir].instantiate()
		door.name = dir.capitalize()
		door.position = marker.position
		doors_node.add_child(door)

func spawn_items() -> void:
	var spawn_points = $ItemSpawn.get_children()
	var item_count = randi_range(min_items, max_items)
	spawn_points.shuffle()
	for i in range(min(item_count, spawn_points.size())):
		var item = item_scenes.pick_random().instantiate()
		item.position = spawn_points[i].position
		add_child(item)
