extends Node2D

# Export the path to the next room scene
@export var next_room_scene: String = "res://scenes/rooms/room_2.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Door ready: ", name)

func _on_exit_area_2d_body_entered(body: CharacterBody2D) -> void:
	if body.is_in_group("Player"):
		print("Player entered door!")
		
		# Stops door from detecting player
		# during unloading
		self.set_deferred("monitoring", false)
		
		var main_scene = get_tree().get_current_scene()
		
		# Had issues with doors and collision
		# so this lets the physics collsion
		# process before door does
		main_scene.call_deferred(
			"load_next_room",
			self.get_node_or_null("SpawnPointNextRoom")
			)
			#load_next_room(self.get_node_or_null("SpawnPointNextRoom"))
