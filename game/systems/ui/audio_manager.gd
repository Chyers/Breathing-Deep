extends Node
var config = ConfigFile.new()

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
