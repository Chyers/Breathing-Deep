extends Resource
class_name RoomData

enum RoomType {
	COMBAT,
	ELITE,
	TREASURE,
	BOSS
}

@export var scene: PackedScene
@export var room_type: RoomType = RoomType.COMBAT
@export var base_difficulty: float = 1.0
@export var tags: Array[String] = []
@export var min_floor: int = 1
@export var max_floor: int = 999
