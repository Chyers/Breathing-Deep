extends Node2D

# --- Node References ---
@onready var rooms_node = $YSort/rooms
@onready var player = $YSort/Player
@onready var camera = $Camera2D
@onready var minimap = $Minimap

# --- Room Assets ---
var start_room_scene: String = "res://scenes/rooms/starter_room.tscn"
var possible_rooms = [
	"res://scenes/rooms/room_2.tscn",
	"res://scenes/rooms/room_3.tscn",
	"res://scenes/rooms/room_4.tscn"
]

# --- Grid Algorithm Parameters ---
@export var _dimensions: Vector2i = Vector2i(7, 5)
@export var _start: Vector2i = Vector2i(-1, -1)
@export var _critical_path_length: int = 13
@export var _branches: int = 3
@export var _branch_length: Vector2i = Vector2i(1, 4)

# --- Dungeon State ---
# grid_map: Vector2i -> { "type": String, "scene": String }
var grid_map: Dictionary = {}
var dungeon_grid: Array = []         # Raw 2D grid (mirrors main_scene_2 logic)
var _branch_candidates: Array[Vector2i] = []

var current_room: Node = null
var current_grid_pos: Vector2i = Vector2i.ZERO
var is_transitioning: bool = false

const VIEWPORT_CENTER = Vector2(240, 135)

# Cardinal direction helpers
const DIRECTIONS = {
	"north": Vector2i(0, 1),
	"south": Vector2i(0, -1),
	"east":  Vector2i(1, 0),
	"west":  Vector2i(-1, 0)
}

# --- Lifecycle ---
func _ready() -> void:
	_initialize_grid()
	_place_entrance()
	_generate_path(_start, _critical_path_length, "C")
	_generate_branches()
	_build_grid_map()
	_print_dungeon()
	minimap.initialize(grid_map, current_grid_pos)

	current_grid_pos = _start
	spawn_room(current_grid_pos)

func restart_dungeon() -> void:
	grid_map.clear()
	dungeon_grid.clear()
	_branch_candidates.clear()
	_start = Vector2i(-1, -1)  # Forces random placement again
	_initialize_grid()
	_place_entrance()
	_generate_path(_start, _critical_path_length, "C")
	_generate_branches()
	_build_grid_map()
	_print_dungeon()
	current_grid_pos = _start
	
	minimap.visited_rooms.clear()
	minimap.room_rects.clear()
	minimap.grid_map = grid_map
	minimap._build_minimap()
	
	await spawn_room(current_grid_pos)

# --- Grid Generation (from main_scene_2.gd) ---
func _initialize_grid() -> void:
	dungeon_grid.clear()
	for x in _dimensions.x:
		dungeon_grid.append([])
		for y in _dimensions.y:
			dungeon_grid[x].append(0)

func _place_entrance() -> void:
	if _start.x < 0 or _start.x >= _dimensions.x:
		_start.x = randi_range(0, _dimensions.x - 1)
	if _start.y < 0 or _start.y >= _dimensions.y:
		_start.y = randi_range(0, _dimensions.y - 1)
	dungeon_grid[_start.x][_start.y] = "S"

func _generate_path(from: Vector2i, length: int, marker: String) -> bool:
	if length == 0:
		return true
	var current: Vector2i = from
	var direction: Vector2i
	match randi_range(0, 3):
		0: direction = Vector2i.UP
		1: direction = Vector2i.RIGHT
		2: direction = Vector2i.DOWN
		3: direction = Vector2i.LEFT
	for i in 4:
		var nx = current.x + direction.x
		var ny = current.y + direction.y
		if nx >= 0 and nx < _dimensions.x and ny >= 0 and ny < _dimensions.y and not dungeon_grid[nx][ny]:
			current += direction
			dungeon_grid[current.x][current.y] = marker
			if length > 1:
				_branch_candidates.append(current)
			if _generate_path(current, length - 1, "C"):
				return true
			else:
				_branch_candidates.erase(current)
				dungeon_grid[current.x][current.y] = 0
				current -= direction
		direction = Vector2i(direction.y, -direction.x)
	return false

func _generate_branches() -> void:
	var branches_created: int = 0
	while branches_created < _branches and _branch_candidates.size() > 0:
		var candidate = _branch_candidates[randi_range(0, _branch_candidates.size() - 1)]
		if _generate_path(candidate, randi_range(_branch_length.x, _branch_length.y), str(branches_created + 1)):
			branches_created += 1
		else:
			_branch_candidates.erase(candidate)

func _print_dungeon() -> void:
	var dungeon_as_string: String = ""
	for y in range(_dimensions.y - 1, -1, -1):
		for x in _dimensions.x:
			if dungeon_grid[x][y]:
				dungeon_as_string += "[" + str(dungeon_grid[x][y]) + "]"
			else:
				dungeon_as_string += "   "
		dungeon_as_string += "\n"
	print(dungeon_as_string)

# --- Grid Map Build ---
# Converts the raw dungeon_grid into grid_map: position -> { type, scene }
func _build_grid_map() -> void:
	grid_map.clear()
	for x in _dimensions.x:
		for y in _dimensions.y:
			var cell = dungeon_grid[x][y]
			if typeof(cell) != TYPE_INT:
				var pos = Vector2i(x, y)
				var scene_path = start_room_scene if cell == "S" else possible_rooms.pick_random()
				grid_map[pos] = {
					"type": str(cell),
					"scene": scene_path
				}

# --- Room Spawning ---
func spawn_room(grid_pos: Vector2i, entry_direction: String = "") -> void:
	print("spawn_room called: ", grid_pos, " entry: ",entry_direction, " room count: ", rooms_node.get_child_count )
	
	if not grid_map.has(grid_pos):
		push_error("spawn_room: no room at grid position " + str(grid_pos))
		return

	if current_room:
		current_room.queue_free()
		current_room = null
		await get_tree().process_frame

	var scene_path: String = grid_map[grid_pos]["scene"]
	var room_scene: PackedScene = load(scene_path)
	var new_room = room_scene.instantiate()
	rooms_node.add_child(new_room)

	# Center room on viewport
	var center_marker = new_room.get_node_or_null("Center")
	if center_marker:
		new_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		new_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found in room at ", grid_pos)

	# Determine active doors based on grid neighbors
	var active_doors = _get_active_doors(grid_pos)
	if new_room.has_method("setup_doors"):
		new_room.setup_doors(active_doors)
		
	# Wait one frame so instanced doors can populate scene tree
	await get_tree().process_frame

	# Player spawn: use the opposite door's SpawnPoint, or fall back to room SpawnPoint
	var spawn_node: Node2D = null
	if entry_direction != "":
		var opposite = _opposite_direction(entry_direction)
		# Look for the instanced door under Doors/
		var doors_node = new_room.get_node_or_null("Doors")
		if doors_node:
			for door in doors_node.get_children():
				if door.name.to_lower() == opposite.to_lower():
					spawn_node = door.get_node_or_null("SpawnPoint")
					break

	if not spawn_node:
		spawn_node = new_room.get_node_or_null("SpawnPoint")

	if spawn_node:
		player.global_position = spawn_node.global_position
	else:
		player.global_position = new_room.position
		print("ERROR: No spawn point found in room at ", grid_pos)

	camera.global_position = VIEWPORT_CENTER
	current_room = new_room
	current_grid_pos = grid_pos
	if minimap:
		minimap.update_minimap(current_grid_pos)
	await get_tree().process_frame

# Called by a door trigger in the room scene, passing which door was used
# e.g. door_node calls: get_tree().root.get_node("MainScene").enter_door("north")
func enter_door(direction: String) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	var offset = DIRECTIONS.get(direction, Vector2i.ZERO)
	var target_pos = current_grid_pos + offset
	
	if grid_map.has(target_pos):
		await spawn_room(target_pos, direction)
	else:
		print("No room in direction: ", direction, " from ", current_grid_pos)
	is_transitioning = false

# --- Helpers ---

# Returns array of direction strings where a neighboring room exists
func _get_active_doors(grid_pos: Vector2i) -> Array[String]:
	var active: Array[String] = []
	for dir_name in DIRECTIONS:
		var neighbor = grid_pos + DIRECTIONS[dir_name]
		if grid_map.has(neighbor):
			active.append(dir_name)
	return active

func _opposite_direction(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""
