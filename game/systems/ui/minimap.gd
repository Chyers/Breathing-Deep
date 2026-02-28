extends CanvasLayer

# --- Config ---
const ROOM_SIZE = 8        # pixels per room square
const ROOM_GAP = 2         # pixels between squares
const MARGIN = 10          # distance from screen corner

# Room type colors
const COLORS = {
	"S": Color(0, 1, 0),        # green - start
	"C": Color(0.5, 0.5, 0.5), # grey - critical path
	"1": Color(0.2, 0.6, 1),   # blue - branch 1
	"2": Color(0.2, 0.6, 1),   # blue - branch 2
	"3": Color(0.2, 0.6, 1),   # blue - branch 3
	"B": Color(1, 0, 0),       # red - boss room
	"P": Color(1, 0, 0.8)      # pink - shop/purchase room
}
const CURRENT_ROOM_COLOR = Color(1, 1, 0)   # yellow - player is here
const UNVISITED_COLOR = Color(0.2, 0.2, 0.2, 0) # transparent - visited but shown dimly

@onready var minimap_grid = $MinimapContainer/MinimapGrid

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
		rect.color = Color(0, 0, 0, 0)  # invisible until visited
		rect.visible = false
		# Position relative to grid bounds
		rect.position = Vector2(
			(pos.x - min_x) * (ROOM_SIZE + ROOM_GAP),
			# Flip Y since grid Y increases upward but screen Y increases downward
			-(pos.y - min_y) * (ROOM_SIZE + ROOM_GAP)
		)
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

func update_minimap(new_pos: Vector2i) -> void:
	if room_rects.is_empty():
		return
	if not room_rects.has(new_pos):
		return
	
	# Mark previous current room as visited
	if current_pos in room_rects and current_pos in visited_rooms:
		var prev_rect = room_rects[current_pos]
		var room_type = grid_map[current_pos]["type"]
		prev_rect.color = COLORS.get(room_type, UNVISITED_COLOR)
		prev_rect.visible = true

	current_pos = new_pos

	# Add to visited if not already
	if new_pos not in visited_rooms:
		visited_rooms.append(new_pos)

	# Reveal and color all visited rooms
	for pos in visited_rooms:
		if pos in room_rects:
			var room_type = grid_map[pos]["type"]
			room_rects[pos].color = COLORS.get(room_type, UNVISITED_COLOR)
			room_rects[pos].visible = true

	# Highlight current room yellow
	if new_pos in room_rects:
		room_rects[new_pos].color = CURRENT_ROOM_COLOR
		room_rects[new_pos].visible = true
