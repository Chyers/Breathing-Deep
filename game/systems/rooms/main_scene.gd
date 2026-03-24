extends Node2D

# Node References #
@onready var rooms_node = $YSort/rooms
@onready var player = $YSort/Player
@onready var camera = $Camera2D
@onready var minimap = $Minimap
@onready var music_player = $MusicPlayer

func play_music(track: AudioStream):
	if music_player.stream == track:
		return # don't restart same song
	
	music_player.stop()
	music_player.stream = track
	
	music_player.stream = track
	music_player.stream.loop = true
	
	music_player.play()

# Room Assets #
var start_room_scene: String = "res://scenes/rooms/starter_room.tscn"
var possible_rooms = [
	"res://scenes/rooms/room_2.tscn",
	"res://scenes/rooms/room_3.tscn",
	"res://scenes/rooms/room_4.tscn"
]

# Grid Algorithm Parameters #
@export var _dimensions: Vector2i = Vector2i(7, 5)
@export var _start: Vector2i = Vector2i(-1, -1)
@export var _critical_path_length: int = 13
@export var _branches: int = 3
@export var _branch_length: Vector2i = Vector2i(1, 4)

# Dungeon State #
# grid_map: Vector2i -> { "type": String, "scene": String }
var grid_map: Dictionary = {}
var dungeon_grid: Array = []
var _branch_candidates: Array[Vector2i] = []

var current_room: Node = null
var current_grid_pos: Vector2i = Vector2i.ZERO
var is_transitioning: bool = false

const VIEWPORT_CENTER = Vector2(240, 135)

# Cardinal Direction Helpers #
# Used for connecting doors, room transitions,
# and neighbor lookups
const DIRECTIONS = {
	"north": Vector2i(0, 1),
	"south": Vector2i(0, -1),
	"east":  Vector2i(1, 0),
	"west":  Vector2i(-1, 0)
}

func _generate_dungeon() -> void:
	grid_map.clear()
	dungeon_grid.clear()
	_branch_candidates.clear()
	_start = Vector2i(-1, -1)
	_initialize_grid()
	_place_entrance()
	_generate_path(_start, _critical_path_length, "C")
	_generate_branches()
	_build_grid_map()
	_place_boss_room()
	_print_dungeon()
	current_grid_pos = _start

# Lifecycle #
func _ready() -> void:
	_generate_dungeon()
	await spawn_room(current_grid_pos)
	minimap.initialize(grid_map, current_grid_pos)

func restart_dungeon() -> void:
	_generate_dungeon()
	minimap.visited_rooms.clear()
	minimap.room_rects.clear()
	minimap.grid_map = grid_map
	minimap._build_minimap()
	await spawn_room(current_grid_pos)

# Grid Generation #
# Fills dungeon grid w zeros
func _initialize_grid() -> void:
	dungeon_grid.clear()
	for x in _dimensions.x:
		dungeon_grid.append([])
		for y in _dimensions.y:
			dungeon_grid[x].append(0)

# Chooses random cell and places entrance
func _place_entrance() -> void:
	if _start.x < 0 or _start.x >= _dimensions.x:
		_start.x = randi_range(1, _dimensions.x - 2)
	if _start.y < 0 or _start.y >= _dimensions.y:
		_start.y = randi_range(1, _dimensions.y - 2)
	dungeon_grid[_start.x][_start.y] = "S"

# Recursive backtracking DFS generator for path
# Picks random direction and attempts to make room there.
# If call succeeds, keeps path. If fails, erases cell 
# and tries new direction
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
			if nx == 0 and ny == 0:
				direction = Vector2i(direction.y, -direction.x)
				continue
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

# Picks random candidate rooms from crit path and tries to grow
# a branch of rand length from each
func _generate_branches() -> void:
	var branches_created: int = 0
	while branches_created < _branches and _branch_candidates.size() > 0:
		var candidate = _branch_candidates[randi_range(0, _branch_candidates.size() - 1)]
		if _generate_path(candidate, randi_range(_branch_length.x, _branch_length.y), str(branches_created + 1)):
			branches_created += 1
		else:
			_branch_candidates.erase(candidate)

# Debug func
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

# Grid Map Build #
# Converts dungeon_grid markers into grid_map dictionary
# and assigns scene paths to each room
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

# Searches for furthest reachable crit path room
# from start and places boss room (so long as boss room
# does not hae any stranded neighbors)
# Also uses boss position to place shop room
func _place_boss_room() -> void:
	# Collect all "C" rooms sorted by distance from start, furthest first
	var candidates: Array = []
	for pos in grid_map.keys():
		if grid_map[pos]["type"] == "C":
			var dist = _start.distance_to(Vector2(pos.x, pos.y))
			candidates.append({ "pos": pos, "dist": dist })
	candidates.sort_custom(func(a, b): return a["dist"] > b["dist"])

	# Pick the furthest candidate where every neighbor has at least one other neighbor
	var boss_pos: Vector2i = Vector2i(-1, -1)
	for candidate in candidates:
		var pos: Vector2i = candidate["pos"]
		var strands_a_room = false
		for dir in DIRECTIONS.values():
			var neighbor = pos + dir
			if not grid_map.has(neighbor):
				continue
			# Count how many connections this neighbor has excluding the candidate
			var other_connections = 0
			for dir2 in DIRECTIONS.values():
				var neighbor_of_neighbor = neighbor + dir2
				if neighbor_of_neighbor != pos and grid_map.has(neighbor_of_neighbor):
					other_connections += 1
			if other_connections == 0:
				strands_a_room = true
				break
		if not strands_a_room:
			boss_pos = pos
			break

	# Fallback: use the furthest room regardless
	if boss_pos == Vector2i(-1, -1):
		push_warning("No ideal boss candidate found - using furthest room.")
		boss_pos = candidates[0]["pos"]

	grid_map[boss_pos]["type"] = "B"
	grid_map[boss_pos]["scene"] = "res://scenes/rooms/boss_room.tscn"
	dungeon_grid[boss_pos.x][boss_pos.y] = "B"
	_place_shop_room(boss_pos)


# BFS from start, only stepping through ciritical path rooms.
# Returns an ordered Array[Vector2i] from start (exclusive) to boss (inclusive),
# or an empty one if no path exists.
# Also used by _place_shop_room() to find midpoint of main route
func _find_critical_path_to_boss(boss_pos: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary = {}   # Vector2i -> Vector2i  (child -> parent)
	var queue: Array[Vector2i] = [_start]
	came_from[_start] = _start

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		if current == boss_pos:
			# Reconstruct path from boss back to start, then reverse
			var path: Array[Vector2i] = []
			var step: Vector2i = boss_pos
			while step != _start:
				path.append(step)
				step = came_from[step]
			path.reverse()   # now ordered start -> boss (start is excluded)
			return path

		for dir in DIRECTIONS.values():
			var neighbor: Vector2i = current + dir
			if came_from.has(neighbor):
				continue
			if not grid_map.has(neighbor):
				continue
			var t: String = grid_map[neighbor]["type"]
			# Walk any room type - branch rooms sitting between C rooms must
			# not create false dead-ends that break the path to the boss
			if t != "S":
				came_from[neighbor] = current
				queue.append(neighbor)

	return []

# Places shop at midpoint of crit path between start and boss
func _place_shop_room(boss_pos: Vector2i) -> void:
	# Walk the actual connected path from start -> boss and pick the midpoint.
	var path: Array[Vector2i] = _find_critical_path_to_boss(boss_pos)

	if path.size() < 3:
		push_warning("Critical path too short to place a shop!")
		return

	# Filter path down to only "C" rooms so the shop never lands on a branch room,
	# then pick the middle of that filtered list.
	var critical_only: Array[Vector2i] = []
	for p in path:
		if grid_map[p]["type"] == "C":
			critical_only.append(p)

	if critical_only.size() < 1:
		push_warning("No C rooms on path to place shop!")
		return

	var mid_index: int = critical_only.size() / 2
	var shop_pos: Vector2i = critical_only[mid_index]

	grid_map[shop_pos]["type"] = "P"
	grid_map[shop_pos]["scene"] = "res://scenes/rooms/shop_room.tscn"
	dungeon_grid[shop_pos.x][shop_pos.y] = "P"
	print("Shop placed at path index %d / %d : %s" % [mid_index, critical_only.size() - 1, str(shop_pos)])

# Room Spawning #
# Handles loading, instantiating, and positioning rooms
# Also repositions player at correct spawn point based on
# which door they entered from
func spawn_room(grid_pos: Vector2i, entry_direction: String = "") -> void:
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
	
	if grid_map[grid_pos]["type"] == "B":
		new_room.is_boss_room = true
	
	rooms_node.add_child(new_room)

	# Center room in viewport using Center marker
	var center_marker = new_room.get_node_or_null("Center")
	if center_marker:
		new_room.position = VIEWPORT_CENTER - center_marker.position
	else:
		new_room.position = VIEWPORT_CENTER
		print("WARNING: No Center marker found in room at ", grid_pos)

	# Tells room which doors to spawn based on its neighbors
	var active_doors = _get_active_doors(grid_pos)
	if new_room.has_method("setup_doors"):
		new_room.setup_doors(active_doors)

	await get_tree().process_frame

	# Spawn player at door they came through, or default spawn
	var spawn_node: Node2D = null
	if entry_direction != "":
		var opposite = _opposite_direction(entry_direction)
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

# Handles player walking through a door and prevents
# double-transitions
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

# Helpers #
# Returns the directions in which this room has a neighbor, uses the
# "_boss" suffix when the neighbor is the boss room so setup_doors() can
# spawn the correct door.
func _get_active_doors(grid_pos: Vector2i) -> Array[String]:
	var active: Array[String] = []
	for dir_name in DIRECTIONS:
		var neighbor = grid_pos + DIRECTIONS[dir_name]
		if grid_map.has(neighbor):
			if grid_map[neighbor]["type"] == "B":
				active.append(dir_name + "_boss")
			else:
				active.append(dir_name)
	return active

func _opposite_direction(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""
