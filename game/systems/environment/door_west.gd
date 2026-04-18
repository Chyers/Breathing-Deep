extends Area2D

const DIRECTION = "west"
var can_use: bool = true
var audio_player: AudioStreamPlayer2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Door ready: ", name)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player") or not can_use:
		return

	var main_scene = get_tree().get_current_scene()
	if main_scene.is_transitioning:
		print("Door blocked - already transitioning")
		return
		
	print("Player entered ", DIRECTION, "door!")
	can_use = false
	
	DoorAudio.play_door_sound()
		
	# Disable monitoring safely
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
		
	# Load next room safely
	main_scene.enter_door(DIRECTION)
