extends Node2D

const DIRECTION = "north"

# Boss doors are one-way — the player can enter the boss room through this
# door but there is no trigger to leave. The door is purely visual on the
# exit side; body_entered is intentionally never connected.
const IS_BOSS_DOOR = true

func _ready() -> void:
	print("Boss door ready: ", name)
