extends CanvasLayer

# Config #
const ROOM_SIZE = 8        # Pixels per room square
const ROOM_GAP = 2         # Pixels between squares
const MARGIN = 10          # Distance from screen corner

# Room type colors
const COLORS = {
	"S": Color(0, 1, 0),        # Green - start
	"C": Color(0.5, 0.5, 0.5), # Grey - critical path
	"1": Color(0.2, 0.6, 1),   # Blue - branch 1
	"2": Color(0.2, 0.6, 1),   # Blue - branch 2
	"3": Color(0.2, 0.6, 1),   # Blue - branch 3
	"B": Color(1, 0, 0),       # Red - boss room
	"P": Color(1, 0, 0.8)      # Pink - shop/purchase room
}
const CURRENT_ROOM_COLOR = Color(1, 1, 0)   # Yellow - player is here
const UNVISITED_COLOR = Color(0.2, 0.2, 0.2, 0) # Transparent
const FOG_COLOR = Color(1, 1, 1, 0.6) # Semi-transparent

@onready var minimap_grid = $MinimapContainer/MinimapGrid
@onready var minimap_lines = $MinimapContainer/MinimapLines

var grid_map: Dictionary = {}
var visited_rooms: Array[Vector2i] = []
var current_pos: Vector2i = Vector2i(-1, -1)
var room_rects: Dictionary = {}  # Vector2i -> ColorRect

func _ready() -> void:
	# Anchor to top right corner
	var container = $MinimapContainer
	container.anchor_left = 1.0
	container.anchor_top = 0.0
	container.anchor_right = 1.0
	container.anchor_bottom = 0.0
	container.offset_left = -MARGIN
	container.offset_top = 40

func initialize(map: Dictionary, start_pos: Vector2i) -> void:
	print("Minimap initialize called! Map size: ", map.size())
	grid_map = map
	_build_minimap()
	update_minimap(start_pos)

func _build_minimap() -> void:
	# Clear existing
	for child in minimap_grid.get_children():
		child.queue_free()
	room_rects.clear()

	# Find grid bounds for positioning
	var min_x = INF
	var min_y = INF
	for pos in grid_map.keys():
		if pos.x < min_x: min_x = pos.x
		if pos.y < min_y: min_y = pos.y

	# Create a ColorRect for every room in the grid
	for pos in grid_map.keys():
		var rect = ColorRect.new()
		rect.size = Vector2(ROOM_SIZE, ROOM_SIZE)
		rect.color = Color(0, 0, 0, 0)  # Invisible until visited
		rect.visible = false
		# Position relative to grid bounds
		rect.position = Vector2(
			(pos.x - min_x) * (ROOM_SIZE + ROOM_GAP),
			# Flip Y since grid Y increases upward but screen Y increases downward
			-(pos.y - min_y) * (ROOM_SIZE + ROOM_GAP)
		)
		
		var room_type = grid_map[pos]["type"]
		var icon_path = _get_room_icon(room_type)
		if icon_path != "":
			var icon = TextureRect.new()
			icon.texture = load(icon_path)
			icon.size = Vector2(ROOM_SIZE, ROOM_SIZE)
			icon.position = Vector2(0, 0)
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.name = "RoomIcon"
			rect.add_child(icon)

		minimap_grid.add_child(rect)
		room_rects[pos] = rect

	# Offset minimap grid so it sits neatly in the corner
	var total_width = 0
	var total_height = 0
	for pos in grid_map.keys():
		var r = room_rects[pos]
		total_width = max(total_width, r.position.x + ROOM_SIZE)
		total_height = max(total_height, abs(r.position.y) + ROOM_SIZE)

	minimap_grid.position = Vector2(-total_width, total_height * 0.1)
	
	minimap_lines.queue_redraw()
	minimap_lines.position = minimap_grid.position
	_draw_connections()

func update_minimap(new_pos: Vector2i) -> void:
	if room_rects.is_empty():
		return
	if not room_rects.has(new_pos):
		return

	current_pos = new_pos

	# Add to visited if not already
	if new_pos not in visited_rooms:
		visited_rooms.append(new_pos)

	for pos in grid_map.keys():
		if not room_rects.has(pos):
			continue
		if pos in visited_rooms:
			var room_type = grid_map[pos]["type"]
			room_rects[pos].color = COLORS.get(room_type, UNVISITED_COLOR)
			room_rects[pos].visible = true
			var icon = room_rects[pos].get_node_or_null("RoomIcon")
			if icon and room_type in ["1", "2", "3"]:
				icon.visible = false
		else:
			room_rects[pos].visible = false
			room_rects[pos].color = Color(0, 0, 0, 0)
	
	const DIRECTIONS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for pos in visited_rooms:
		for dir in DIRECTIONS:
			var neighbor = pos + dir
			if neighbor in visited_rooms:
				continue
			if not grid_map.has(neighbor):
				continue
			if not room_rects.has(neighbor):
				continue
			room_rects[neighbor].visible = true
			room_rects[neighbor].color = FOG_COLOR
	
	room_rects[new_pos].color = CURRENT_ROOM_COLOR
	room_rects[new_pos].visible = true
	
	_draw_connections()

func _draw_connections() -> void:
	minimap_lines.room_rects = room_rects
	minimap_lines.grid_map = grid_map
	minimap_lines.visited_rooms = visited_rooms
	minimap_lines.queue_redraw()

func _get_room_icon(room_type: String) -> String:
	match room_type:
		"B": return "res://assets/ui/boss_icon.png"
		"P": return "res://assets/ui/shop_icon.png"
		"1", "2", "3":
			return "res://assets/ui/bonus_icon.png"
	return ""
