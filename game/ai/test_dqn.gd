extends Node

var manager: EncounterManager

func _ready() -> void:
	# DirAccess.remove_absolute(OS.get_user_data_dir() + "/dqn_weights.json") # Deletes json file to restart training
	manager = EncounterManager.new()
	add_child(manager)
	run_simulation()

func simulate_outcome(encounter_type: int, floor_scalar: float, hp_ratio: float) -> Array:
	# Returns [damage_taken, player_died]
	# Rough difficulty curve per type
	var base_damage: float
	match encounter_type:
		0: base_damage = 0.35  # SWARM   — many weak hits
		1: base_damage = 0.40  # RANGED  — moderate, avoidable
		2: base_damage = 0.55  # BRUISER — high single hits
		3: base_damage = 0.38  # FLANKER — moderate, positional
		4: base_damage = 0.65  # ELITE   — hardest single enemy
		5: base_damage = 0.45  # MIXED   — moderate spread
		_: base_damage = 0.40
	var difficulty = base_damage + floor_scalar * 0.2
	var damage: float = clamp(difficulty * randf_range(0.8, 1.2), 0.0, 1.0)
	var death_threshold: float = clamp(hp_ratio * 0.8 + 0.2, 0.65, 1.0)
	var died: bool = damage > death_threshold
	return [damage, died]

func run_simulation() -> void:
	manager.telemetry.total_rooms = 300
	print("\n=== DQN TRAINING SIMULATION ===\n")

	for room in range(300):
		# Simulates a floor scalar that increases with depth
		var floor_scalar: float = clamp(float(room) / 300.0, 0.0, 1.0)

		# Simulates player HP gradually draining over the run
		var hp_ratio: float = clamp(1.0 - (float(room) / 300.0), 0.1, 1.0)

		print("--- Room %d | floor_scalar=%.2f | hp_ratio=%.2f ---" % [room + 1, floor_scalar, hp_ratio])

		# Starts the encounter
		manager.start_encounter(floor_scalar, hp_ratio)
		
		manager.telemetry.room_start_time -= randf_range(60.0, 240.0)

		# Simulates room outcome — vary damage and deaths to stress the reward signal
		var outcome := simulate_outcome(manager.last_action, floor_scalar, hp_ratio)
		var damage_taken: float = outcome[0]
		var player_died: bool = outcome[1]
		

		print("  damage_taken=%.2f | player_died=%s" % [damage_taken, player_died])

		# Ends encounter — logs reward, pushes to replay buffer, trains if buffer is ready
		manager.end_encounter(damage_taken, player_died, floor_scalar, hp_ratio)

		if room % 10 == 0:
			print("Room %d | buf=%d | train_step=%d | eps=%.4f | state=%s" % [
				room + 1,
				manager.dqn.replay_buffer.size(),
				manager.dqn.train_step,
				manager.dqn.epsilon,
				manager.telemetry.get_state_vector(floor_scalar, hp_ratio)
			])

	print("\n=== SAVING WEIGHTS ===")
	manager.save_session()
	print("Done. Run again to confirm weights load and epsilon resumes from saved value.")

# | What healthy output looks like |
# | `Spawning X enemies` printed each room | Confirms `choose_action()` → `spawn_encounter()` pipeline is connected |
# | `state_vector` has exactly 11 values | Confirms input size matches `INPUT_SIZE` |
# | `buffer_size` climbs to 64 then training begins | Confirms `MIN_BUFFER_SIZE` gate is working |
# | `train_step` increments after buffer fills | Confirms `train_on_batch()` is being called |
# | `epsilon` slowly decreasing from 0.20 | Confirms decay is running |
# | `Weights saved` message at the end | Confirms file write succeeded |
# | Second run prints `Weights loaded` and epsilon starts below 0.20 | Confirms persistence is working across sessions |
