extends Node
class_name EncounterManager

var dqn: DQN
var telemetry: Telemetry

var _current_state: Array = []
var _last_action: int = -1
var last_action: int = -1
func _ready() -> void:
	dqn = DQN.new()       # _init() auto-loads saved weights if they exist
	telemetry = Telemetry.new()
	add_child(telemetry)

# Encounter lifecycle

# Called at the start of each room.
# floor_scalar: normalized floor depth [0, 1]
# hp_ratio:     player current HP / max HP [0, 1]
func start_encounter(floor_scalar: float, hp_ratio: float) -> void:
	telemetry.start_room()
	_current_state = telemetry.get_state_vector(floor_scalar, hp_ratio)
	_last_action = dqn.choose_action(_current_state)
	last_action = _last_action
	spawn_encounter(_last_action)

# Called when the room ends.
# damage_taken: raw damage dealt this room / player max HP → normalized [0, 1]
func end_encounter(
	damage_taken: float, 
	player_died: bool,
	floor_scalar: float, 
	hp_ratio: float
	) -> void:
	telemetry.end_room(damage_taken, player_died)
	var next_state := telemetry.get_state_vector(floor_scalar, hp_ratio)
	var time_delta := telemetry.get_avg_clear_time_delta()
	var reward : float = dqn.get_reward(
		damage_taken, 
		player_died, 
		time_delta, 
		hp_ratio, 
		floor_scalar,
		_last_action
	)
	dqn.add_experience(_current_state, _last_action, reward, next_state, player_died)
	dqn.train_on_batch()

# Spawning

func spawn_encounter(encounter_type: int) -> void:
	match encounter_type:
		EncounterTypes.EncounterType.SWARM:
			print("Spawning SWARM enemies")
		EncounterTypes.EncounterType.RANGED:
			print("Spawning RANGED enemies")
		EncounterTypes.EncounterType.BRUISER:
			print("Spawning BRUISER enemies")
		EncounterTypes.EncounterType.FLANKER:
			print("Spawning FLANKER enemies")
		EncounterTypes.EncounterType.ELITE:
			print("Spawning ELITE enemies")
		EncounterTypes.EncounterType.MIXED:
			print("Spawning MIXED enemies")

# Persistence

# Call at natural checkpoints: between floors, on quit, on game-over screen, etc.
func save_session() -> void:
	dqn.save_weights()
