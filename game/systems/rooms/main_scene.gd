extends Node2D

@onready var rooms_node = $YSort/rooms
@onready var player = $YSort/Player
@onready var camera = $Camera2D

var start_room_scene: String = "res://scenes/rooms/starter_room.tscn"
var current_room: Node = null
var dungeon_rooms: Array = []
var current_room_index: int = 0
var current_room_path: String = ""
var is_transitioning: bool = false
var active_room_count: int = 0

var possible_rooms = [
	"res://scenes/rooms/room_2.tscn",
	"res://scenes/rooms/room_3.tscn",
	"res://scenes/rooms/room_4.tscn"
	# For now this will load any room
	# placed in the array, later we may
	# have diff arrays holding diff types
	# of rooms
]

const VIEWPORT_CENTER = Vector2(240, 135)

func _ready():
	generate_dungeon(5) # N-1 number of rooms
	spawn_room(dungeon_rooms[0])
	
func spawn_room(scene_path: String, spawn_marker: Node2D = null) -> void:
	if current_room:
		current_room.queue_free()  # Remove immediately, not deferred
		active_room_count -= 1
		current_room = null
		
		await get_tree().process_frame
	
	# Load new room
	var room_scene: PackedScene = load(scene_path)
	var new_room = room_scene.instantiate()
	rooms_node.add_child(new_room)
	current_room_path = scene_path

	# Center room
	var center_marker = new_room.get_node_or_null("Center")
	if center_marker:
		new_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		new_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found, placing room at viewport center")

	# Player spawn
	var target_spawn = spawn_marker
	if not target_spawn:
		target_spawn = new_room.get_node_or_null("SpawnPoint")

	if target_spawn:
		player.call_deferred("set_global_position", new_room.position + target_spawn.position)
	else:
		player.call_deferred("set_global_position", new_room.position)
		print("ERROR: No spawn point found in room: ", new_room.name)

	# Camera
	camera.call_deferred("set_global_position", VIEWPORT_CENTER)

	# Now remove previous room safely
	if current_room and current_room != new_room:
		current_room.call_deferred("queue_free")
		active_room_count -= 1

	current_room = new_room
	
func generate_dungeon(room_count):
	dungeon_rooms.clear()
	current_room_index = 0
	
	# First room
	dungeon_rooms.append(start_room_scene)
	
	# Middle rooms
	for i in range(room_count):
		dungeon_rooms.append(possible_rooms.pick_random())
		
	print("Dungeon generated:", dungeon_rooms)

func load_next_room(spawn_marker: Node2D = null):
	
	if current_room_index >= dungeon_rooms.size() - 1:
		print("Dungeon complete!")
		return
		
	is_transitioning = true
	current_room_index += 1

	var next_room = dungeon_rooms[current_room_index]
	spawn_room(next_room, spawn_marker)

	await get_tree().process_frame
	is_transitioning = false

func pick_next_room(previous_room: String) -> String:
	if possible_rooms.size() < 2:
		return possible_rooms[0]
		
	var next_room = previous_room
	while next_room == previous_room:
		next_room = possible_rooms.pick_random()
	return next_room
