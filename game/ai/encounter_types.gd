extends Node
class_name EncounterTypes

enum EncounterType {
	SWARM,
	BRUISER,
	FLANKER,
	ELITE,
	MIXED
}

enum Variant {
	SINGLE,
	WAVE,
	AMBUSH,
	SPLIT,
	ELITE_PLUS_MINIONS
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
