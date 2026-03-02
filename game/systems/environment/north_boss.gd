extends Node2D

const DIRECTION = "north"

# Boss door visuals are one-way (going into room they are shown but not going out)
const IS_BOSS_DOOR = true

func _ready() -> void:
	print("Boss door ready: ", name)
