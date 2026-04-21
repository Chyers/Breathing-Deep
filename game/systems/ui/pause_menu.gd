extends Control

@onready var pause_menu     = $PauseMenu
@onready var dimmer         = $PauseMenu/Dimmer
@onready var settings_panel = $PauseMenu/SettingsPanel
@onready var master_slider  = $PauseMenu/SettingsPanel/VBoxContainer/HBoxContainer/MasterSlider
@onready var music_slider   = $PauseMenu/SettingsPanel/VBoxContainer/HBoxContainer2/MusicSlider

var is_paused: bool = false

func _ready() -> void:
	pause_menu.hide()
	settings_panel.hide()

	# Dimmer setup — semi-transparent black overlay
	dimmer.color = Color(0, 0, 0, 0.55)

	# Slider ranges
	master_slider.min_value = -40.0
	master_slider.max_value = 0.0
	master_slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))

	music_slider.min_value = -40.0
	music_slider.max_value = 0.0
	music_slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))

	# This node must keep processing while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		if settings_panel.visible:
			_close_settings()
		else:
			_toggle_pause()

func _toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		pause_menu.show()
	else:
		pause_menu.hide()
		settings_panel.hide()

# --- Button Callbacks ---

func _on_resume_button_pressed() -> void:
	_toggle_pause()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	pause_menu.hide()
	settings_panel.hide()

	# Calls restart on main_scene — adjust path if yours differs
	var main = get_tree().get_root().get_node_or_null("main_scene")
	if main and main.has_method("restart_dungeon"):
		await main.restart_dungeon()
	else:
		push_error("PauseMenu: Could not find main_scene to restart.")

func _on_settings_button_pressed() -> void:
	settings_panel.show()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _close_settings() -> void:
	settings_panel.hide()

func _on_close_settings_button_pressed() -> void:
	_close_settings()

# --- Settings Callbacks ---

func _on_master_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)

func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), value)
