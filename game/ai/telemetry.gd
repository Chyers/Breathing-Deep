extends Node
class_name Telemetry

# Rolling window metrics
var room_start_time: float   = 0.0
var recent_damage_taken: Array = []
var recent_clear_times: Array  = []
var recent_deaths: Array       = []

# Success tracking
var success_streak: int = 0

# Floor / room progression
var rooms_cleared: int = 0
var total_rooms: int   = 0

# Constants
const METRIC_WINDOW: int         = 10
const TARGET_ROOM_TIME: float    = 150.0
const MAX_DAMAGE: float          = 200.0   # Will be tuned to actual HP cap
const MAX_DAMAGE_VARIANCE: float = 2500.0  # Spread ceiling
const MAX_TIME_VARIANCE: float   = 3600.0

# Room lifecycle

func start_room() -> void:
	room_start_time = Time.get_ticks_msec() / 1000.0

func end_room(damage_taken: float, player_died: bool) -> void:
	var clear_time := (Time.get_ticks_msec() / 1000.0) - room_start_time

	recent_damage_taken.append(damage_taken)
	recent_clear_times.append(clear_time)
	recent_deaths.append(1.0 if player_died else 0.0)

	if recent_damage_taken.size() > METRIC_WINDOW:
		recent_damage_taken.pop_front()
		recent_clear_times.pop_front()
		recent_deaths.pop_front()

	success_streak = 0 if player_died else success_streak + 1
	rooms_cleared += 1

# Metric getters

func get_avg_recent_damage() -> float:
	if recent_damage_taken.is_empty():
		return 0.0
	return recent_damage_taken.reduce(func(a, b): return a + b) / recent_damage_taken.size()

# Normalized version used directly in the state vector
func get_avg_recent_damage_normalized() -> float:
	return clamp(get_avg_recent_damage(), 0.0, 1.0)

func get_avg_clear_time_delta() -> float:
	if recent_clear_times.is_empty():
		return 0.0
	var avg : float = recent_clear_times.reduce(func(a, b): return a + b) / recent_clear_times.size()
	return clamp((avg - TARGET_ROOM_TIME) / TARGET_ROOM_TIME, -1.0, 1.0)

func get_rooms_cleared_ratio() -> float:
	if total_rooms == 0:
		return 0.0
	return clamp(float(rooms_cleared) / float(total_rooms), 0.0, 1.0)

func get_success_streak_normalized() -> float:
	return clamp(float(success_streak) / float(METRIC_WINDOW), 0.0, 1.0)

func get_recent_death_rate() -> float:
	if recent_deaths.is_empty():
		return 0.0
	return recent_deaths.reduce(func(a, b): return a + b) / recent_deaths.size()

# Variance of damage taken — high variance means inconsistent encounters
func get_damage_variance_normalized() -> float:
	if recent_damage_taken.size() < 2:
		return 0.0
	var avg := get_avg_recent_damage()
	var variance := 0.0
	for d in recent_damage_taken:
		variance += (d - avg) * (d - avg)
	variance /= recent_damage_taken.size()
	return clamp(variance / MAX_DAMAGE_VARIANCE, 0.0, 1.0)

# Variance of clear times — high variance means unpredictable pace
func get_time_variance_normalized() -> float:
	if recent_clear_times.size() < 2:
		return 0.0
	var avg : float = recent_clear_times.reduce(func(a, b): return a + b) / recent_clear_times.size()
	var variance := 0.0
	for t in recent_clear_times:
		variance += (t - avg) * (t - avg)
	variance /= recent_clear_times.size()
	return clamp(variance / MAX_TIME_VARIANCE, 0.0, 1.0)

# Positive = damage is climbing, negative = player is improving
func get_damage_trend() -> float:
	if recent_damage_taken.size() < 2:
		return 0.0
	return clamp(
		(recent_damage_taken.back() - recent_damage_taken.front()) / MAX_DAMAGE,
		-1.0, 1.0
	)

# Positive = rooms taking longer, negative = player is speeding up
func get_time_trend() -> float:
	if recent_clear_times.size() < 2:
		return 0.0
	return clamp(
		(recent_clear_times.back() - recent_clear_times.front()) / TARGET_ROOM_TIME,
		-1.0, 1.0
	)

# State vector — 11 features matching DQN.INPUT_SIZE

func get_state_vector(floor_scalar_val: float, hp_ratio: float) -> Array:
	return [
		get_avg_recent_damage_normalized(),   # [0,  1]  how hard hits have been landing
		get_avg_clear_time_delta(),           # [-1, 1]  pace vs target
		clamp(floor_scalar_val, 0.0, 1.0),   # [0,  1]  floor depth pressure
		get_success_streak_normalized(),      # [0,  1]  momentum
		clamp(hp_ratio, 0.0, 1.0),           # [0,  1]  current health
		get_rooms_cleared_ratio(),            # [0,  1]  run progress
		get_recent_death_rate(),              # [0,  1]  recent lethality rate
		get_damage_variance_normalized(),     # [0,  1]  consistency of damage
		get_time_variance_normalized(),       # [0,  1]  consistency of pace
		get_damage_trend(),                   # [-1, 1]  damage trajectory
		get_time_trend()                      # [-1, 1]  pace trajectory
	]

func _ready() -> void:
	pass
