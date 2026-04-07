extends Node2D

# Node References
@onready var rooms_node = $YSort/rooms
@onready var player = $YSort/Player
@onready var camera = $Camera2D
@onready var minimap = $Minimap
@onready var music_player = $MusicPlayer

# Room Assets
var start_room_scene: String = "res://scenes/rooms/starter_room.tscn"
var possible_rooms = [
	"res://scenes/rooms/room_2.tscn",
	"res://scenes/rooms/room_3.tscn",
	"res://scenes/rooms/room_4.tscn"
]

# Grid Algorithm Parameters
@export var _dimensions: Vector2i = Vector2i(7, 5)
@export var _start: Vector2i = Vector2i(-1, -1)
@export var _critical_path_length: int = 13
@export var _branches: int = 3
@export var _branch_length: Vector2i = Vector2i(1, 4)

# Dungeon State
var grid_map: Dictionary = {} # Vector2i -> { "type": String, "scene": String }
var dungeon_grid: Array = []
var _branch_candidates: Array[Vector2i] = []
var room_states: Dictionary = {} # Vector2i -> cached room Node

var current_room: Node = null
var current_grid_pos: Vector2i = Vector2i.ZERO
var is_transitioning: bool = false

const VIEWPORT_CENTER = Vector2(240, 135)
const HIDDEN_ROOM_OFFSET = Vector2(100000, 100000)

const DIRECTIONS = {
	"north": Vector2i(0,  1),
	"south": Vector2i(0, -1),
	"east":  Vector2i(1,  0),
	"west":  Vector2i(-1, 0)
}

# Music
var current_tween: Tween = null

func play_music(track: AudioStream, fade_out: float = 1.0, fade_in: float = 1.5, volume_db: float = 0.0) -> void:
	if music_player.stream == track and music_player.playing:
		return

	# Kill any tween already running
	if current_tween:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.tween_property(music_player, "volume_db", -40.0, fade_out)
	await current_tween.finished

	music_player.stop()
	music_player.stream = track
	music_player.stream.loop = true
	music_player.volume_db = -40.0
	music_player.play()

	current_tween = create_tween()
	current_tween.tween_property(music_player, "volume_db", volume_db, fade_in)

# Lifecycle
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

# Dungeon Generation
func _generate_dungeon() -> void:
	for cached in room_states.values():
		if is_instance_valid(cached):
			cached.queue_free()
	room_states.clear()
	grid_map.clear()
	dungeon_grid.clear()
	_branch_candidates.clear()
	_start = Vector2i(-1, -1)
	current_room = null
	_initialize_grid()
	_place_entrance()
	_generate_path(_start, _critical_path_length, "C")
	_generate_branches()
	_build_grid_map()
	_place_boss_room()
	_print_dungeon()
	current_grid_pos = _start

func _initialize_grid() -> void:
	for x in _dimensions.x:
		dungeon_grid.append([])
		for y in _dimensions.y:
			dungeon_grid[x].append(0)

func _place_entrance() -> void:
	if _start.x < 0 or _start.x >= _dimensions.x:
		_start.x = randi_range(1, _dimensions.x - 2)
	if _start.y < 0 or _start.y >= _dimensions.y:
		_start.y = randi_range(1, _dimensions.y - 2)
	dungeon_grid[_start.x][_start.y] = "S"

func _generate_path(from: Vector2i, length: int, marker: String) -> bool:
	if length == 0:
		return true
	var current := from
	var direction: Vector2i
	match randi_range(0, 3):
		0: direction = Vector2i.UP
		1: direction = Vector2i.RIGHT
		2: direction = Vector2i.DOWN
		3: direction = Vector2i.LEFT
	for i in 4:
		var next = current + direction
		if next.x >= 0 and next.x < _dimensions.x and next.y >= 0 and next.y < _dimensions.y \
				and not dungeon_grid[next.x][next.y] and next != Vector2i.ZERO:
			current = next
			dungeon_grid[current.x][current.y] = marker
			if length > 1:
				_branch_candidates.append(current)
			if _generate_path(current, length - 1, "C"):
				return true
			_branch_candidates.erase(current)
			dungeon_grid[current.x][current.y] = 0
			current = next - direction
		direction = Vector2i(direction.y, -direction.x)
	return false

func _generate_branches() -> void:
	var branches_created := 0
	while branches_created < _branches and _branch_candidates.size() > 0:
		var candidate = _branch_candidates[randi_range(0, _branch_candidates.size() - 1)]
		if _generate_path(candidate, randi_range(_branch_length.x, _branch_length.y), str(branches_created + 1)):
			branches_created += 1
		else:
			_branch_candidates.erase(candidate)

func _build_grid_map() -> void:
	for x in _dimensions.x:
		for y in _dimensions.y:
			var cell = dungeon_grid[x][y]
			if typeof(cell) != TYPE_INT:
				var pos = Vector2i(x, y)
				grid_map[pos] = {
					"type": str(cell),
					"scene": start_room_scene if cell == "S" else possible_rooms.pick_random()
				}

func _place_boss_room() -> void:
	var candidates: Array = []
	for pos in grid_map.keys():
		if grid_map[pos]["type"] == "C":
			candidates.append({ "pos": pos, "dist": _start.distance_to(Vector2(pos.x, pos.y)) })
	candidates.sort_custom(func(a, b): return a["dist"] > b["dist"])

	var boss_pos := Vector2i(-1, -1)
	for candidate in candidates:
		var pos: Vector2i = candidate["pos"]
		var strands_a_room := false
		for dir in DIRECTIONS.values():
			var neighbor = pos + dir
			if not grid_map.has(neighbor):
				continue
			var other_connections := 0
			for dir2 in DIRECTIONS.values():
				var nn = neighbor + dir2
				if nn != pos and grid_map.has(nn):
					other_connections += 1
			if other_connections == 0:
				strands_a_room = true
				break
		if not strands_a_room:
			boss_pos = pos
			break

	if boss_pos == Vector2i(-1, -1):
		push_warning("No ideal boss candidate found - using furthest room.")
		boss_pos = candidates[0]["pos"]

	grid_map[boss_pos]["type"] = "B"
	grid_map[boss_pos]["scene"] = "res://scenes/rooms/boss_room.tscn"
	dungeon_grid[boss_pos.x][boss_pos.y] = "B"
	_place_shop_room(boss_pos)

func _place_shop_room(boss_pos: Vector2i) -> void:
	var path := _find_critical_path_to_boss(boss_pos)
	if path.size() < 3:
		push_warning("Critical path too short to place a shop!")
		return

	var critical_only: Array[Vector2i] = []
	for p in path:
		if grid_map[p]["type"] == "C":
			critical_only.append(p)
	if critical_only.is_empty():
		push_warning("No C rooms on path to place shop!")
		return

	var mid_index := critical_only.size() / 2
	var shop_pos := critical_only[mid_index]
	grid_map[shop_pos]["type"] = "P"
	grid_map[shop_pos]["scene"] = "res://scenes/rooms/shop_room.tscn"
	dungeon_grid[shop_pos.x][shop_pos.y] = "P"
	print("Shop placed at path index %d / %d : %s" % [mid_index, critical_only.size() - 1, str(shop_pos)])

func _find_critical_path_to_boss(boss_pos: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary = { _start: _start }
	var queue: Array[Vector2i] = [_start]
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		if current == boss_pos:
			var path: Array[Vector2i] = []
			var step := boss_pos
			while step != _start:
				path.append(step)
				step = came_from[step]
			path.reverse()
			return path
		for dir in DIRECTIONS.values():
			var neighbor: Vector2i = current + dir
			if came_from.has(neighbor) or not grid_map.has(neighbor):
				continue
			if grid_map[neighbor]["type"] != "S":
				came_from[neighbor] = current
				queue.append(neighbor)
	return []

# Room Spawning
func spawn_room(grid_pos: Vector2i, entry_direction: String = "") -> void:
	if not grid_map.has(grid_pos):
		push_error("spawn_room: no room at grid position " + str(grid_pos))
		return

	if current_room:
		current_room.hide()
		current_room.set_process(false)
		current_room.set_physics_process(false)
		current_room.position += HIDDEN_ROOM_OFFSET
		var nav_region = current_room.get_node_or_null("NavigationRegion2D")
		if nav_region:
			nav_region.enabled = false

	var cached_room := _get_cached_room(grid_pos)
	var new_room: Node

	if cached_room:
		new_room = cached_room
		new_room.position -= HIDDEN_ROOM_OFFSET
		new_room.show()
		new_room.set_process(true)
		new_room.set_physics_process(true)
		_reset_room_doors(new_room)
		var nav_region = new_room.get_node_or_null("NavigationRegion2D")
		if nav_region:
			nav_region.enabled = true
	else:
		var room_scene: PackedScene = load(grid_map[grid_pos]["scene"])
		new_room = room_scene.instantiate()
		if grid_map[grid_pos]["type"] == "B":
			new_room.is_boss_room = true
		rooms_node.add_child(new_room)
		room_states[grid_pos] = new_room
		var center_marker = new_room.get_node_or_null("Center")
		new_room.position = VIEWPORT_CENTER - center_marker.position if center_marker \
				else VIEWPORT_CENTER
		if not center_marker:
			push_warning("No Center marker found in room at " + str(grid_pos))
		var active_doors := _get_active_doors(grid_pos)
		if new_room.has_method("setup_doors"):
			new_room.setup_doors(active_doors)

	await get_tree().process_frame

	var spawn_node: Node2D = null
	if entry_direction != "":
		var doors_node = new_room.get_node_or_null("Doors")
		if doors_node:
			for door in doors_node.get_children():
				if door.name.to_lower() == _opposite_direction(entry_direction):
					spawn_node = door.get_node_or_null("SpawnPoint")
					break
	if not spawn_node:
		spawn_node = new_room.get_node_or_null("SpawnPoint")
	if spawn_node:
		player.global_position = spawn_node.global_position
	else:
		player.global_position = new_room.position
		push_error("No spawn point found in room at " + str(grid_pos))

	camera.global_position = VIEWPORT_CENTER
	current_room = new_room
	current_grid_pos = grid_pos
	minimap.update_minimap(current_grid_pos)
	await get_tree().process_frame

	var room_type: String = grid_map[grid_pos]["type"]
	if room_type == "B":
		play_music(preload("res://audio/Boss Battle.ogg"), 1.0, 1.5, -10.0)
	else:
		play_music(preload("res://audio/Memoraphile - Spooky Dungeon.mp3"), 0.3, 0.8)

func enter_door(direction: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var target_pos : Vector2i = current_grid_pos + DIRECTIONS.get(direction, Vector2i.ZERO)
	if grid_map.has(target_pos):
		await spawn_room(target_pos, direction)
	else:
		push_warning("No room in direction: " + direction + " from " + str(current_grid_pos))
	is_transitioning = false

# Helpers
func _get_cached_room(grid_pos: Vector2i) -> Node:
	if room_states.has(grid_pos) and is_instance_valid(room_states[grid_pos]):
		return room_states[grid_pos]
	return null

func _get_active_doors(grid_pos: Vector2i) -> Array[String]:
	var active: Array[String] = []
	for dir_name in DIRECTIONS:
		var neighbor : Vector2i = grid_pos + DIRECTIONS[dir_name]
		if grid_map.has(neighbor):
			active.append(dir_name + "_boss" if grid_map[neighbor]["type"] == "B" else dir_name)
	return active

func _opposite_direction(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""

func _reset_room_doors(room: Node) -> void:
	var doors_node := room.get_node_or_null("Doors")
	if not doors_node:
		return
	_reset_doors_recursive(doors_node)

func _reset_doors_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Area2D:
			if "can_use" in child:
				child.can_use = true
			child.set_deferred("monitoring", true)
			child.set_deferred("monitorable", true)
		_reset_doors_recursive(child)

# Debug
func _print_dungeon() -> void:
	var output := ""
	for y in range(_dimensions.y - 1, -1, -1):
		for x in _dimensions.x:
			output += "[" + str(dungeon_grid[x][y]) + "]" if dungeon_grid[x][y] else "   "
		output += "\n"
	print(output)
