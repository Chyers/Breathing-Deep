extends Node

var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.volume_db = -18.0

func play_door_sound(is_boss: bool) -> void:
	if is_boss:
		audio_player.stream = preload("res://audio/dragon-studio-heavy-door-unlocking-515258.mp3")
	else:
		audio_player.stream = preload("res://audio/soundreality-opening-door-411632.mp3")
	
	audio_player.play()
