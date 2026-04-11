extends Node2D

@export var min_items: int = 1
@export var max_items: int = 4
@export var is_boss_room: bool = false
@export var already_visited: bool = false
@export var min_enemies: int = 1
@export var max_enemies: int = 3
@export var enemy_scenes: Array[PackedScene] = []

var item_scenes = [
	preload("res://scenes/environment/coin.tscn"),
	preload("res://scenes/environment/health.tscn"),
	preload("res://scenes/environment/buff.tscn")
]

const DOOR_SCENES = {
	"north": preload("res://scenes/environment/door/door_north.tscn"),
	"south": preload("res://scenes/environment/door/door_south.tscn"),
	"east":  preload("res://scenes/environment/door/door_east.tscn"),
	"west":  preload("res://scenes/environment/door/door_west.tscn"),
	"north_boss": preload("res://scenes/environment/door/north_boss.tscn"),
	"south_boss": preload("res://scenes/environment/door/south_boss.tscn"),
	"east_boss":  preload("res://scenes/environment/door/east_boss.tscn"),
	"west_boss":  preload("res://scenes/environment/door/west_boss.tscn"),
}

func _ready() -> void:
	randomize()
	if not is_boss_room:
		spawn_items()
		spawn_enemies()
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
		var base_dir = dir.replace("_boss", "")
		var marker = get_node_or_null("DoorMarkers/" + base_dir.capitalize())
		if not marker:
			push_warning("No DoorMarker found for direction: " + base_dir + " in room " + name)
			continue

		var door = DOOR_SCENES[dir].instantiate()
		door.name = base_dir.capitalize()
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

func spawn_enemies() -> void:
	print("=== spawn_enemies called in: ", name)
	print("enemy_scenes size: ", enemy_scenes.size())
	
	if enemy_scenes.is_empty():
		print("EXIT: enemy_scenes is empty")
		return
		
	var spawn_points = get_node_or_null("EnemySpawn")
	if not spawn_points:
		print("EXIT: No EnemySpawn node found in ", name)
		return
		
	var points = spawn_points.get_children()
	print("Spawn points found: ", points.size())
	
	if points.is_empty():
		print("EXIT: EnemySpawn has no Marker2D children")
		return

	var enemy_count = randi_range(min_enemies, max_enemies)
	print("Trying to spawn ", enemy_count, " enemies")
	points.shuffle()
	
	for i in range(min(enemy_count, points.size())):
		var enemy = enemy_scenes.pick_random().instantiate()
		add_child(enemy)
		enemy.global_position = points[i].global_position  # uses global_position since parent is changing
		print("Spawning enemy at: ", enemy.global_position)
		print("Enemy added: ", enemy.name)
