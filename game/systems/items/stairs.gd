extends Node2D

func _on_exit_area_2d_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		print("Player used stairs!")
		var main_scene = get_tree().get_current_scene()
		main_scene.restart_dungeon()
