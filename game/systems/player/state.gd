class_name State extends Node

const Player = preload("res://systems/player/player.gd")
static var player: Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

#What happens when the player enters this state
func Enter() -> void:
	pass

#What happens when the player exits this state
func Exit() -> void:
	pass

func process( _delta : float ) -> State:
	return null

func physics( _delta : float ) -> State:
	return null

func handleInput( _event: InputEvent) -> State:
	return null
