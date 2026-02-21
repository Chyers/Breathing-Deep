extends Node
class_name EncounterManager

# Import encounter types
var EncounterType = preload("res://ai/encounter_types.gd")

func select_random_encounter() -> int:
	return randi() % 6 # Randomly pick 1 of 6 enconter types

func spawn_encounter(encounter_type: int):
	match encounter_type:
		EncounterType.SWARM:
			print("Spawning SWARM enemies")
		EncounterType.RANGED:
			print("Spawning RANGED enemies")
		EncounterType.BRUISER:
			print("Spawning BRUISER enemies")
		EncounterType.FLANKER:
			print("Spawning FLANKER enemies")
		EncounterType.ELITE:
			print("Spawning ELITE enemies")
		EncounterType.MIXED:
			print("Spawning MIXED enemies")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
