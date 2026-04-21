extends RefCounted
class_name DQN

# Architecture
const INPUT_SIZE: int = 11   # Must match Telemetry.get_state_vector() length
const HIDDEN1_SIZE: int = 32
const HIDDEN2_SIZE: int = 16
const OUTPUT_SIZE: int = 5    # One Q-value per EncounterType

# Online network weights
var weights1: Array = []  # INPUT_SIZE × HIDDEN1_SIZE
var weights2: Array = []  # HIDDEN1_SIZE × HIDDEN2_SIZE
var weights3: Array = []  # HIDDEN2_SIZE × OUTPUT_SIZE

# Target network weights (frozen copy, synced every TARGET_UPDATE_FREQ steps)
var target_weights1: Array = []
var target_weights2: Array = []
var target_weights3: Array = []

# Replay buffer
var replay_buffer: Array = []
const BUFFER_MAX_SIZE: int = 2000
const BATCH_SIZE: int = 32
const MIN_BUFFER_SIZE: int = 64   # Training won't begin until buffer has this many entries

# Hyperparameters
var epsilon: float = 1.0
const EPSILON_MIN: float = 0.05
const EPSILON_DECAY: float = 0.9999
const ALPHA: float = 0.003  # Learning rate — lowered for stability
const GAMMA: float = 0.95   # Discount factor

# Target network sync schedule
var train_step: int = 0
const TARGET_UPDATE_FREQ: int  = 20     # Sync target weights every N training steps

# Persistence
const WEIGHTS_PATH: String = "user://dqn_weights.json"
#

var last_action: int = -1
const EXPECTED_DIFFICULTY: Array[float] = [
		0.35, # SWARM
		0.55, # BRUISER
		0.38, # FLANKER
		0.65, # ELITE
		0.45  # MIXED
	]

func _init() -> void:
	initialize_weights()
	load_weights()   # Silently overwrites random init if a save file exists

func initialize_weights() -> void:
	weights1 = _random_matrix(INPUT_SIZE, HIDDEN1_SIZE)
	weights2 = _random_matrix(HIDDEN1_SIZE, HIDDEN2_SIZE)
	weights3 = _random_matrix(HIDDEN2_SIZE, OUTPUT_SIZE)
	_sync_target_network()

# Matrix utilities

# Xavier / Glorot uniform init — improves early gradient flow vs plain [-0.5, 0.5]
func _random_matrix(rows: int, cols: int) -> Array:
	var scale := sqrt(2.0 / float(rows + cols))
	var matrix := []
	for i in range(rows):
		var row := []
		for j in range(cols):
			row.append(randf_range(-scale, scale))
		matrix.append(row)
	return matrix

func _zero_matrix(rows: int, cols: int) -> Array:
	var matrix := []
	for i in range(rows):
		var row := []
		for j in range(cols):
			row.append(0.0)
		matrix.append(row)
	return matrix

func _deep_copy_matrix(src: Array) -> Array:
	var copy := []
	for row in src:
		copy.append(row.duplicate())
	return copy

# Multiplies a 1-D input vector by a 2-D weight matrix: output[j] = Σ input[i]*W[i][j]
func _matmul(inputs: Array, weights: Array) -> Array:
	var output := []
	for j in weights[0].size():
		var sum := 0.0
		for i in inputs.size():
			sum += inputs[i] * weights[i][j]
		output.append(sum)
	return output

# Activation

func _relu(x: float) -> float:
	return max(0.0, x)

func _relu_deriv(x: float) -> float:
	return 1.0 if x > 0.0 else 0.0

# Forward pass

# Full forward pass caching all pre- and post-activation values for backprop.
# Returns [output, h2, z2, h1, z1] where z = pre-activation, h = post-activation.
func _forward_cached(input: Array, w1: Array, w2: Array, w3: Array) -> Array:
	var z1 := _matmul(input, w1)
	var h1 := []
	for v in z1:
		h1.append(_relu(v))

	var z2 := _matmul(h1, w2)
	var h2 := []
	for v in z2:
		h2.append(_relu(v))

	var output := _matmul(h2, w3)
	return [output, h2, z2, h1, z1]

# Public forward — uses online network, no cache needed externally
func forward(input: Array) -> Array:
	return _forward_cached(input, weights1, weights2, weights3)[0]

func _forward_target(input: Array) -> Array:
	return _forward_cached(input, target_weights1, target_weights2, target_weights3)[0]

# Target network

func _sync_target_network() -> void:
	target_weights1 = _deep_copy_matrix(weights1)
	target_weights2 = _deep_copy_matrix(weights2)
	target_weights3 = _deep_copy_matrix(weights3)

# Action selection

func choose_action(state: Array) -> int:
	if randf() < epsilon:
		var random_action = randi() % OUTPUT_SIZE
		last_action = random_action
		return random_action
	var q_values := forward(state)
	
	if last_action != -1:
		q_values[last_action] -= 0.05
		
	var best_action := 0
	var best_value : float = q_values[0]
	
	for i in range(1, q_values.size()):
		if q_values[i] > best_value:
			best_value = q_values[i]
			best_action = i
	
	last_action = best_action
	return best_action

# Reward
#
# damage_taken  — normalized damage this room [0, 1]  (raw_damage / player_max_hp)
# player_died   — hard failure flag
# clear_time_delta — from Telemetry.get_avg_clear_time_delta(), range [-1, 1]
# hp_ratio      — player HP / max HP at room end [0, 1]
#
# Returns a continuous reward in [-1.0, 1.0].
# Components:
#   Damage (50%) — punishes tanking hits, rewards clean clears
#   Time   (30%) — rewards clearing near the target pace, penalises extremes
#   HP     (20%) — rewards finishing with more health remaining
#
func get_reward(
	damage_taken: float, 
	player_died: bool, 
	clear_time_delta: float, 
	hp_ratio: float, 
	floor_scalar: float, 
	action: int
) -> float:
	if player_died:
		return -1.0

	# damage_score: 0 damage → +1.0, full damage → -0.5
	var damage_score : float = lerp(1.0, -0.5, clamp(damage_taken, 0.0, 1.0))
	# time_score: on-target → +1.0, maximally off-target → 0.0
	var time_score : float = 1.0 - clamp(abs(clear_time_delta), 0.0, 1.0)
	# survival_score: full HP → 1.0, empty → 0.0
	var survival_score : float = clamp(hp_ratio, 0.0, 1.0)
	
	# Low HP Scaling
	var low_hp_penalty := 1.0 - hp_ratio
	damage_score *= (1.0 + low_hp_penalty * 0.5)
	
	# Floor Difficulty Bonus
	var difficulty_bonus := floor_scalar * 0.2
	
	# Action-aware Difficulty Alignment
	var expected_difficulty: float = EXPECTED_DIFFICULTY[action]
	
	var target_difficulty: float = lerp(0.3, 0.7, floor_scalar)
	var difficulty_alignment: float = clamp(
		1.0 - abs(expected_difficulty - target_difficulty),
		0.0,
		1.0
	)
	
	# Final Reward
	var reward : float = (
		damage_score * 0.40 +
		time_score * 0.20 +
		survival_score * 0.15 +
		difficulty_alignment * 0.15 +
		difficulty_bonus * 0.10
	)

	return clamp(reward, -1.0, 1.0)

# Replay buffer

func add_experience(state: Array, action: int, reward: float,
					next_state: Array, done: bool) -> void:
	replay_buffer.append([state, action, reward, next_state, done])
	if replay_buffer.size() > BUFFER_MAX_SIZE:
		replay_buffer.pop_front()

func _sample_batch() -> Array:
	var buffer_size := replay_buffer.size()
	var actual_batch : int = min(BATCH_SIZE, buffer_size)
	var picked: Dictionary = {}
	while picked.size() < actual_batch:
		picked[randi() % buffer_size] = true
	var batch := []
	for idx in picked.keys():
		batch.append(replay_buffer[idx])
	return batch

# Training — full backpropagation through all three layers

func train_on_batch() -> void:
	if replay_buffer.size() < MIN_BUFFER_SIZE:
		return

	var batch := _sample_batch()

	# Gradient accumulators — same dimensions as the weight matrices
	var grad_w1 := _zero_matrix(INPUT_SIZE,   HIDDEN1_SIZE)
	var grad_w2 := _zero_matrix(HIDDEN1_SIZE, HIDDEN2_SIZE)
	var grad_w3 := _zero_matrix(HIDDEN2_SIZE, OUTPUT_SIZE)

	for transition in batch:
		var state: Array = transition[0]
		var action: int = transition[1]
		var reward: float = transition[2]
		var next_state: Array = transition[3]
		var done: bool = transition[4]

		# Forward pass on online network, cache activations
		var fwd := _forward_cached(state, weights1, weights2, weights3)
		var q_values: Array = fwd[0]
		var h2: Array = fwd[1]
		var z2: Array = fwd[2]
		var h1: Array = fwd[3]
		var z1: Array = fwd[4]

		# Bellman target via frozen target network
		var next_q := _forward_target(next_state)
		var max_next : float = next_q[0]
		for v in next_q:
			if v > max_next:
				max_next = v

		var target_q : float = reward if done else reward + GAMMA * max_next
		var td_error : float = target_q - q_values[action]

		# Output layer delta
		# Only the action that was taken receives a non-zero gradient;
		# all other output neurons are left unchanged (DQN property).
		var delta3 := []
		for j in OUTPUT_SIZE:
			delta3.append(0.0)
		delta3[action] = td_error

		for i in HIDDEN2_SIZE:
			for j in OUTPUT_SIZE:
				grad_w3[i][j] += delta3[j] * h2[i]

		# Hidden layer 2 delta
		var delta2 := []
		for j in HIDDEN2_SIZE:
			var g := 0.0
			for k in OUTPUT_SIZE:
				g += delta3[k] * weights3[j][k]
			delta2.append(g * _relu_deriv(z2[j]))

		for i in HIDDEN1_SIZE:
			for j in HIDDEN2_SIZE:
				grad_w2[i][j] += delta2[j] * h1[i]

		# Hidden layer 1 delta
		var delta1 := []
		for j in HIDDEN1_SIZE:
			var g := 0.0
			for k in HIDDEN2_SIZE:
				g += delta2[k] * weights2[j][k]
			delta1.append(g * _relu_deriv(z1[j]))

		for i in INPUT_SIZE:
			for j in HIDDEN1_SIZE:
				grad_w1[i][j] += delta1[j] * state[i]

	# Apply averaged gradients
	var n := float(batch.size())

	for i in HIDDEN2_SIZE:
		for j in OUTPUT_SIZE:
			var g : float = clamp(grad_w3[i][j] / n, -1.0, 1.0)
			weights3[i][j] += ALPHA * g

	for i in HIDDEN1_SIZE:
		for j in HIDDEN2_SIZE:
			var g : float = clamp(grad_w2[i][j] / n, -1.0, 1.0)
			weights2[i][j] += ALPHA * g

	for i in INPUT_SIZE:
		for j in HIDDEN1_SIZE:
			var g : float = clamp(grad_w1[i][j] / n, -1.0, 1.0)
			weights1[i][j] += ALPHA * g

	# Housekeeping
	train_step += 1
	if train_step % TARGET_UPDATE_FREQ == 0:
		_sync_target_network()

	epsilon = max(EPSILON_MIN, epsilon * EPSILON_DECAY)

# Weight persistence

func save_weights() -> void:
	var data := {
		"weights1":        weights1,
		"weights2":        weights2,
		"weights3":        weights3,
		"target_weights1": target_weights1,
		"target_weights2": target_weights2,
		"target_weights3": target_weights3,
		"epsilon":         epsilon,
		"train_step":      train_step
	}
	var file := FileAccess.open(WEIGHTS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("DQN: Cannot write weights to %s" % WEIGHTS_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("DQN: Weights saved → ", WEIGHTS_PATH)

func load_weights() -> bool:
	if not FileAccess.file_exists(WEIGHTS_PATH):
		print("DQN: No save file found, starting with fresh weights.")
		return false
	var file := FileAccess.open(WEIGHTS_PATH, FileAccess.READ)
	if file == null:
		push_error("DQN: Cannot read weights from %s" % WEIGHTS_PATH)
		return false
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("DQN: Weights file is malformed, falling back to fresh init.")
		return false

	var d: Dictionary = json.data
	weights1 = _to_float_matrix(d["weights1"])
	weights2 = _to_float_matrix(d["weights2"])
	weights3 = _to_float_matrix(d["weights3"])
	target_weights1 = _to_float_matrix(d["target_weights1"])
	target_weights2 = _to_float_matrix(d["target_weights2"])
	target_weights3 = _to_float_matrix(d["target_weights3"])
	epsilon = float(d["epsilon"])
	train_step = int(d["train_step"])

	print("DQN: Weights loaded ← ", WEIGHTS_PATH)
	return true

# JSON deserialises numbers as Variants; this ensures every value is a proper float
func _to_float_matrix(raw: Array) -> Array:
	var matrix := []
	for row in raw:
		var new_row := []
		for val in row:
			new_row.append(float(val))
		matrix.append(new_row)
	return matrix
