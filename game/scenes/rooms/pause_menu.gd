extends Control

func toggle_pause():
	get_tree().paused = !get_tree().paused
	visible = get_tree().paused
