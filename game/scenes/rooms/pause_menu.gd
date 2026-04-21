extends CanvasLayer

@onready var dimmer = $Dimmer
@onready var settings_panel = $SettingsPanel
@onready var pause_panel = $Panel
@onready var slider = $SettingsPanel.get_node("VBoxContainer/HBoxContainer/VolumeSlider")
@onready var click_sound = $ClickSound

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()
	settings_panel.hide()

	dimmer.color = Color(0, 0, 0, 0.55)

	slider.value = AudioManager.volume
	AudioManager.volume_changed.connect(_on_volume_changed)

# -------------------------
# INPUT
# -------------------------
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if settings_panel.visible:
			settings_panel.go_back()
		else:
			_toggle_pause()

# -------------------------
# PAUSE
# -------------------------
func _toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		show()
		pause_panel.show()
	else:
		hide()
		settings_panel.hide()
		pause_panel.show()

# -------------------------
# BUTTONS
# -------------------------
func _on_resume_button_pressed() -> void:
	settings_panel.hide()
	pause_panel.show()
	_toggle_pause()

func _on_settings_button_pressed() -> void:
	settings_panel.open_options("pause")

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	is_paused = false

	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().quit()


# -------------------------
# AUDIO
# -------------------------

func _on_volume_slider_value_changed(value):
	if value != AudioManager.volume:
		AudioManager.set_volume(value)
		click_sound.play() 

func _on_volume_changed(value):
	if slider.value != value:
		slider.value = value
