extends Node2D

@onready var exit_area: Area2D = $ExitArea2D
@onready var sprite = $Sprite2D          # adjust to your actual sprite node name
var _unlocked: bool = false

func _ready() -> void:
	# Hide and disable on load
	visible = false
	exit_area.monitoring = false
	exit_area.monitorable = false

func unlock() -> void:
	_unlocked = true
	visible = true
	exit_area.monitoring = true
	exit_area.monitorable = true

func _on_exit_area_2d_body_entered(body: Node) -> void:
	if not _unlocked:
		return
	if body.is_in_group("Player"):
		print("Player used stairs!")
		var main_scene = get_tree().get_current_scene()
		main_scene.restart_dungeon()
