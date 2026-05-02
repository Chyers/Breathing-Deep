extends Node2D

@export var min_items: int = 1
@export var max_items: int = 4
@export var is_boss_room: bool = false
@export var already_visited: bool = false
@export var min_enemies: int = 1
@export var max_enemies: int = 3
@export var enemy_scenes: Array[PackedScene] = []

var _boss_ref: Node = null
var _enemy_refs: Array[Node] = []

var item_scenes = [
	preload("res://scenes/environment/coin.tscn"),
	preload("res://scenes/environment/health.tscn"),
	preload("res://scenes/environment/buff.tscn")
]

const DOOR_SCENES = {
	"north": preload("res://scenes/environment/door/door_north.tscn"),
	"south": preload("res://scenes/environment/door/door_south.tscn"),
	"east": preload("res://scenes/environment/door/door_east.tscn"),
	"west": preload("res://scenes/environment/door/door_west.tscn"),
	"north_boss": preload("res://scenes/environment/door/north_boss.tscn"),
	"south_boss": preload("res://scenes/environment/door/south_boss.tscn"),
	"east_boss": preload("res://scenes/environment/door/east_boss.tscn"),
	"west_boss": preload("res://scenes/environment/door/west_boss.tscn"),
}

func _ready() -> void:
	randomize()

# Called by main_scene.gd after instantiation
func setup_doors(active_directions: Array[String]) -> void:
	var doors_node = get_node_or_null("Doors")
	if not doors_node:
		push_warning("Room has no Doors node: " + name)
		return

	# Clears any leftover doors from a previous load (safety net)
	for child in doors_node.get_children():
		child.queue_free()

	for dir in active_directions:
		if not DOOR_SCENES.has(dir):
			push_warning("No door scene registered for direction: " + dir)
			continue

		# Finds the marker that tells us where to place this door
		var base_dir = dir.replace("_boss", "")
		var marker = get_node_or_null("DoorMarkers/" + base_dir.capitalize())
		if not marker:
			push_warning("No DoorMarker found for direction: " + base_dir + " in room " + name)
			continue

		var door = DOOR_SCENES[dir].instantiate()
		door.name = base_dir.capitalize()
		door.position = marker.position
		doors_node.add_child(door)

func spawn_enemies(injected_enemies: Array = []) -> void:
	var spawn_points = get_node_or_null("EnemySpawn")
	if not spawn_points:
		return
	var points = spawn_points.get_children()
	if points.is_empty() or injected_enemies.is_empty():
		return
	points.shuffle()
	for i in range(min(injected_enemies.size(), points.size())):
		var enemy = injected_enemies[i]
		add_child(enemy)
		enemy.global_position = points[i].global_position
		print("Spawned %s (%s) at %s" % [enemy.name, enemy.get("max_health"), enemy.global_position])

		if is_boss_room:
			_enemy_refs.append(enemy)            # ← register every enemy
			enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))

			if enemy.has_signal("boss_defeated"):
				_boss_ref = enemy

	if is_boss_room:
		await get_tree().process_frame
		_lock_doors(true)

func _on_enemy_removed(enemy: Node) -> void:
	_enemy_refs.erase(enemy)
	print("Enemy removed, %d remaining" % _enemy_refs.size())

	if _enemy_refs.is_empty():
		_on_room_cleared()

func _on_room_cleared() -> void:
	var stairs = get_node_or_null("Stairs")
	if stairs and stairs.has_method("unlock"):
		stairs.unlock()
	_lock_doors(false)
	print("Boss room cleared — stairs unlocked!")

func _on_boss_defeated() -> void:
	print("Boss defeated — waiting for room clear…")

func _lock_doors(locked: bool) -> void:
	var doors_node = get_node_or_null("Doors")
	if not doors_node:
		return
	for door in doors_node.get_children():
		# Grabs the Area2D regardless of its directional name
		var area = door.find_child("*ExitArea2D", true, false)
		if area:
			area.set_deferred("monitoring", not locked)
			area.set_deferred("monitorable", not locked)
			var col = area.get_node_or_null("CollisionShape2D")
			if col:
				col.set_deferred("disabled", locked)
