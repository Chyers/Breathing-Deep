extends Node2D

@onready var rooms_node = $YSort/rooms
@onready var player = $YSort/Player
@onready var camera = $Camera2D

var start_room_scene: String = "res://scenes/rooms/starter_scene.tscn"
var current_room: Node = null

const VIEWPORT_CENTER = Vector2(240, 135)

func _ready():
	spawn_room(start_room_scene)

func spawn_room(scene_path: String, spawn_marker: Node2D = null) -> void:
	# Remove previous room
	if current_room:
		current_room.queue_free()
	
	# Load and instantiate new room
	var room_scene = load(scene_path)
	current_room = room_scene.instantiate()
	rooms_node.add_child(current_room)
	
	# Center room using 'Center' marker if it exists
	var center_marker = current_room.get_node_or_null("Center")
	if center_marker:
		current_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		current_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found, placing room at viewport center")
	
	# Determine spawn point
	var target_spawn = spawn_marker
	if not target_spawn:
		target_spawn = current_room.get_node_or_null("SpawnPoint")

	if target_spawn:
		player.global_position = current_room.position + target_spawn.position
	else:
		player.global_position = current_room.position
		print("ERROR: No spawn point found in room: ", current_room.name)
	
	# Snap camera to room center
	camera.global_position = VIEWPORT_CENTER
