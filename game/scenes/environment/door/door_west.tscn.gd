const DIRECTION = "south"
var can_use: bool = true
var audio_player: AudioStreamPlayer2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


		
	print("Player entered ", DIRECTION, "door!")
	can_use = false
	
	DoorAudio.play_door_sound()
		
	# Disable monitoring safely
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
		
	# Load next room safely
	main_scene.enter_door(DIRECTION)
