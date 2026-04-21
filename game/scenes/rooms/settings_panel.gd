extends Control

var opened_from = "main"

@onready var pause_panel = $"../Panel"
@onready var main_menu = $"../VBoxContainer"

func _ready():
	hide()

func open_options(from):
	opened_from = from   # ✅ THIS LINE FIXES EVERYTHING

	show()

	if main_menu:
		main_menu.hide()

	if pause_panel:
		pause_panel.hide()

func go_back():
	hide()

	if opened_from == "main" and main_menu:
		main_menu.show()

	elif opened_from == "pause" and pause_panel:
		pause_panel.show()

func _on_back_button_pressed() -> void:
	go_back()
