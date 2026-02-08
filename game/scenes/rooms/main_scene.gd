extends Node2D

@onready var rooms_node = $rooms
@onready var player = $Player
@onready var camera = $Camera2D

var start_room_scene = preload("res://scenes/rooms/starter_scene.tscn")
var current_room: Node = null

const VIEWPORT_CENTER = Vector2(240, 135)

func _ready():
	spawn_start_room()

func spawn_start_room():
	current_room = start_room_scene.instantiate()
	rooms_node.add_child(current_room)

	# Align room's center to viewport
	var center_marker = current_room.get_node_or_null("Center")
	if center_marker:
		current_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		current_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found, placing room at viewport center")
	
	# Place player at room's SpawnPoint
	var spawn_point = current_room.get_node_or_null("SpawnPoint")
	if spawn_point:
		player.global_position = current_room.position + spawn_point.position
	else:
		print("ERROR: SpawnPoint not found in room: ", current_room.name)
	
	# Snap camera to room's center
	camera.global_position = VIEWPORT_CENTER
	
func spawn_room(scene_path: String, spawn_marker: Node2D = null) -> void:
	
	# Remove old room
	if current_room:
		current_room.queue_free()
		
	# Load and instantiate the new room
	var room_scene = load(scene_path)
	if not room_scene:
		print("ERROR: Could not load scene: ", scene_path)
		return

	current_room = room_scene.instantiate()
	rooms_node.add_child(current_room)

	# Align room's center to viewport
	var center_marker = current_room.get_node_or_null("Center")
	if center_marker:
		current_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		current_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found, placing room at viewport center")

	# Move player to spawn_marker (usually door) or fallback
	var target_spawn = spawn_marker
	if not target_spawn:
		target_spawn = current_room.get_node_or_null("SpawnPoint")

	if target_spawn:
		player.global_position = current_room.position + target_spawn.position
	else:
		print("ERROR: No spawn point found in room: ", current_room.name)
		player.global_position = current_room.position

	# Snap camera to viewport center
	camera.global_position = VIEWPORT_CENTER
