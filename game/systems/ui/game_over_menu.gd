extends CanvasLayer

@onready var score_label = $Dimmer/CenterContainer/VBoxContainer/FinalScoreLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func show_game_over():
	show()
	get_tree().paused = true
	
	var final_score = ScoreManager.get_score()
	score_label.text = "Final Score: " + str(final_score)

# -------------------------
# BUTTONS
# -------------------------

func _on_retry_button_pressed():
	get_tree().paused = false
	ScoreManager.reset_score()
	get_tree().reload_current_scene()
	
func _on_main_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
