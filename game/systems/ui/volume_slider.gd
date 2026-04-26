extends HSlider

func _ready():
	value_changed.connect(_on_value_changed)

func _on_value_changed(value):
	var bus_index = AudioServer.get_bus_index("Master")
	
	# Prevent -inf (mute crash issue)
	if value <= 0.01:
		AudioServer.set_bus_volume_db(bus_index, -80)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
