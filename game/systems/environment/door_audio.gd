extends Node

var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = preload("res://audio/soundreality-opening-door-411632.mp3")
	audio_player.volume_db = -18.0

func play_door_sound() -> void:
	audio_player.play()
