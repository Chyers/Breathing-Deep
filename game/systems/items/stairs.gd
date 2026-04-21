extends Node2D

@onready var exit_area: Area2D = $ExitArea2D
@onready var sprite = $Sprite2D
@onready var stair_sound: AudioStreamPlayer2D = $StairSound

var _unlocked: bool = false
var _used: bool = false  # prevents multiple triggers

func _ready() -> void:
	visible = false
	exit_area.monitoring = false
	exit_area.monitorable = false

func unlock() -> void:
	_unlocked = true
	visible = true
	exit_area.monitoring = true
	exit_area.monitorable = true

func _on_exit_area_2d_body_entered(body: Node) -> void:
	if not _unlocked or _used:
		return
		
	if body.is_in_group("player"):
		_used = true
		print("Player used stairs!")
		
		AudioManager.play_sound(stair_sound.stream)

		var main_scene = get_tree().get_current_scene()
		main_scene.restart_dungeon()
