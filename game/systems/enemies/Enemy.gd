extends CharacterBody2D

@export var speed := 40
@export var max_health := 3
var health := max_health
var direction := Vector2.LEFT


func _ready():
	$AnimationPlayer.play("idle")
	

func attack():
	$AnimationPlayer.play("attack")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
