extends Node2D

# Export the path to the next room scene
@export var next_room_scene: String = "res://scenes/rooms/next_room.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Door ready: ", name)

func _on_exit_area_2d_body_entered(body: CharacterBody2D) -> void:
	if body.is_in_group("Player"):
		print("Player entered door!")  # debug
		var main_scene = get_tree().get_current_scene()
		main_scene.enter_room(next_room_scene, self)
