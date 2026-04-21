extends Node

signal fullscreen_changed(value)
signal volume_changed(value)

var fullscreen := false
var volume := 1.0

var config = ConfigFile.new()

# -------------------------
# SETTERS
# -------------------------
func set_fullscreen(value: bool):
	if fullscreen == value:
		return

	fullscreen = value

	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	fullscreen_changed.emit(value)
	save_settings()


func set_volume(value: float):
	if volume == value:
		return

	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

	volume_changed.emit(value)
	save_settings()

# -------------------------
# SAVE / LOAD
# -------------------------
func save_settings():
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("audio", "volume", volume)
	config.save("user://settings.cfg")


func load_settings():
	var err = config.load("user://settings.cfg")

	if err == OK:
		fullscreen = config.get_value("display", "fullscreen", false)
		volume = config.get_value("audio", "volume", 1.0)

	set_fullscreen(fullscreen)
	set_volume(volume)
