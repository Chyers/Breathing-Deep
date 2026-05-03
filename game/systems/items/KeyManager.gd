extends Node

const MAX_KEYS: int = 3
var keys_assigned: int = 0
var c_rooms_total: int = 0
var c_rooms_visited: int = 0
var keys_dropped: int = 0

func reset() -> void:
	keys_assigned = 0
	c_rooms_total = 0
	c_rooms_visited = 0
	keys_dropped = 0

func keys_remaining() -> int:
	return MAX_KEYS - keys_assigned

func rooms_remaining() -> int:
	return c_rooms_total - c_rooms_visited

func should_assign_key() -> bool:
	if keys_assigned >= MAX_KEYS:
		return false
	if (MAX_KEYS - keys_assigned) >= rooms_remaining():
		return true
	var chance: float = float(MAX_KEYS - keys_assigned) / float(rooms_remaining())
	return randf() < chance

func register_assignment() -> void:
	keys_assigned += 1
	print("register_assignment called, keys_assigned now: ", keys_assigned)
	print(get_stack())

func can_drop() -> bool:
	return keys_dropped < MAX_KEYS

func register_drop() -> void:
	keys_dropped += 1
