extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_exit_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var player = body as CharacterBody2D
		player.queue_free()
		
	await get_tree().create_timer(3.0).timeout
	print("scene transition")
	pass # Replace with function body.
