extends Node2D

@onready var rooms_node = $rooms
@onready var player = $Player
@onready var camera = $Camera2D

var start_room_scene = preload("res://scenes/rooms/starter_scene.tscn")
var current_room: Node = null

func _ready():
	spawn_start_room()

func spawn_start_room():
	current_room = start_room_scene.instantiate()
	rooms_node.add_child(current_room)

	# Place player at spawn
	var spawn_point = current_room.get_node_or_null("SpawnPoint")
	if spawn_point:
		player.global_position = spawn_point.global_position
	else:
		print("ERROR: SpawnPoint not found in room: ", current_room.name)

	# Position room at origin
	rooms_node.global_position = Vector2.ZERO

	# Snap camera to room center
	var room_center = current_room.get_node("Center").global_position
	camera.global_position = room_center


# Called by the door when player touches it
func enter_room(next_room_scene_path: String, door: Node2D) -> void:
	if current_room:
		current_room.queue_free()

	# Spawn the next room
	var next_room_scene = load(next_room_scene_path)
	current_room = next_room_scene.instantiate()
	rooms_node.add_child(current_room)

	# Place player at the door's SpawnPointNextRoom marker
	var spawn_point = door.get_node_or_null("SpawnPointNextRoom")
	if spawn_point:
		player.global_position = current_room.global_position + spawn_point.position
	else:
		print("ERROR: SpawnPointNextRoom not found on door")
		var fallback = current_room.get_node("SpawnPoint")
		player.global_position = fallback.global_position
