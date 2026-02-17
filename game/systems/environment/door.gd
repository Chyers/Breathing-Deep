extends Node2D

@onready var exit_area = $ExitArea2D
var can_use: bool = true

func _ready() -> void:
	print("Door ready: ", name)

func _on_exit_area_2d_body_entered(body: Node) -> void:
	if not body.is_in_group("Player") or not can_use:
		return

	var main_scene = get_tree().get_current_scene()
	if main_scene.is_transitioning:
		print("Door blocked - already transitioning")
		return
		
	print("Player entered door!")
	can_use = false
		
	# Disable monitoring safely
	exit_area.set_deferred("monitoring", false)
	exit_area.set_deferred("monitorable", false)
		
	# Load next room safely
	main_scene.call_deferred(
		"load_next_room",
		self.get_node_or_null("SpawnPointNextRoom")
	)
