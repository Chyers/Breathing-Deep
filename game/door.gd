extends Area2D

@onready var audio = $AudioStreamPlayer2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		audio.play()  # Plays sound when player enters
