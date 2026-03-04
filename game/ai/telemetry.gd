extends Node
class_name Telemetry

# Recent room metrics #
var room_start_time : float = 0.0
var recent_damage_taken : Array = []
var recent_clear_times : Array = []

# Success tracking #
var success_streak : int = 0

# Floor/room progression #
var rooms_cleared : int = 0
var total_rooms : int = 0
var floor_scalar : float = 1.0

# Constants #
const METRIC_WINDOW : int = 5  # Number of recent rooms to track
const TARGET_ROOM_TIME : float = 150.0  # 2-3 minutes = 120-180s, midpoint 150

# Room lifecycle #
func start_room():
	room_start_time = Time.get_ticks_msec() / 1000.0
	
func end_room(damage_taken: float, player_died: bool):
	var clear_time = (Time.get_ticks_msec() / 1000.0) - room_start_time
	
	# Track recent metrics
	recent_damage_taken.append(damage_taken)
	recent_clear_times.append(clear_time)
	
	if recent_damage_taken.size() > METRIC_WINDOW:
		recent_damage_taken.pop_front()
		recent_clear_times.pop_front()
		# Update success streak
		
	if player_died:
		success_streak = 0
	else:
		success_streak += 1
		
	rooms_cleared += 1

# Average damage taken in recent rooms #
func get_avg_recent_damage() -> float:
	if recent_damage_taken.is_empty():
		return 0.0
	return recent_damage_taken.reduce(func(a,b): return a + b) / recent_damage_taken.size()
	
# Clear time delta from target room time #
func get_avg_clear_time_delta() -> float:
	if recent_clear_times.is_empty():
		return 0.0
	var avg = recent_clear_times.reduce(func(a,b): return a + b) / recent_clear_times.size()
	return clamp((avg - TARGET_ROOM_TIME) / TARGET_ROOM_TIME, -1.0, 1.0)

# Rooms cleared ratio #
func get_rooms_cleared_ratio() -> float:
	if total_rooms == 0:
		return 0.0
	return float(rooms_cleared) / float(total_rooms)

# Recent success streak (normalized) #
func get_success_streak() -> float:
	return clamp(float(success_streak) / METRIC_WINDOW, 0.0, 1.0)

func get_state_vector(floor_scalar_val: float, hp_ratio: float) -> Array:
	# Example without player archetype yet
	return [
		get_avg_recent_damage(),        # normalized externally if needed
		get_avg_clear_time_delta(),
		floor_scalar_val,
		get_success_streak(),
		hp_ratio,
		get_rooms_cleared_ratio()
		]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
