extends Control

const ROOM_SIZE = 8
const ROOM_GAP = 2
const LINE_COLOR_VISITED = Color(0, 0, 0)
const LINE_COLOR_HIDDEN = Color(0, 0, 0, 0)

# Only north and east are used to avoid drawing connections twice
const DIRECTIONS = {
	"east": Vector2i(1, 0),
	"north": Vector2i(0, 1)
}

# Populated by minimap.gd before queue_redraw() is called
var room_rects: Dictionary = {}
var grid_map: Dictionary = {}
var visited_rooms: Array[Vector2i] = []

# Called by Godot whenever queue_redraw() is triggered.
# Draws small rectangle between rooms and its visited neighbors
func _draw() -> void:
	for pos in grid_map.keys():
		# Only draw connections for rooms player has visited
		if not pos in visited_rooms:
			continue
		for dir in DIRECTIONS.values():
			var neighbor = pos + dir
			# Skip if neighbor doesn't exist in dungeon
			if not grid_map.has(neighbor):
				continue
			# Skip if neighbor hasn't been visited yet
			if neighbor not in visited_rooms:
				continue
			
			var a_rect = room_rects.get(pos)
			var b_rect = room_rects.get(neighbor)
			if not a_rect or not b_rect:
				continue
			# Calculate center of each room in local coords
			var a_center = a_rect.position + Vector2(ROOM_SIZE, ROOM_SIZE) * 0.5
			var b_center = b_rect.position + Vector2(ROOM_SIZE, ROOM_SIZE) * 0.5
			
			# Fill gap between two squares
			var gap_rect = Rect2(
				(a_center + b_center) * 0.5 - Vector2(ROOM_GAP, ROOM_GAP) * 0.5,
				Vector2(ROOM_GAP, ROOM_GAP)
			)
			draw_rect(gap_rect, LINE_COLOR_VISITED)
