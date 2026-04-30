extends Node
var config = ConfigFile.new()
var player: AudioStreamPlayer   # ✅ global player

func set_volume(value):
	volume = value

	# Apply volume (example)
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

	emit_signal("volume_changed", value)

	save_settings()   # ✅ ALWAYS save here


func save_settings():
	config.set_value("audio", "volume", volume)
	config.save("user://settings.cfg")


func load_settings():
	if config.load("user://settings.cfg") == OK:
		volume = config.get_value("audio", "volume", 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))
signal volume_changed(value)

var volume: float = 1.0

func play_sound(sound: AudioStream):
	var p = AudioStreamPlayer.new()
	add_child(p)
	
	p.stream = sound
	p.play()
	
	p.finished.connect(func(): p.queue_free())
	
	
