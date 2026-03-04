extends RefCounted
class_name DQN

var input_size = 11
var hidden1_size = 16
var hidden2_size = 8
var output_size = 6

var weights1 = []
var weights2 = []
var weights3 = []

var epsilon = 0.2
var epsilon_min = 0.05
var epsilon_decay = 0.999
var alpha = 0.005
var gamma = 0.95

func _init():
	initialize_weights()

func initialize_weights() -> void:
	# Randomly initialize weights1, weights2, weights3
	# as 2D arrays of floats
	# weights1: input -> hidden1 (11 x 16)
	weights1 = _random_matrix(input_size, hidden1_size)
	# weights2: hidden1 -> hidden2 (16 x 8)
	weights2 = _random_matrix(hidden1_size, hidden2_size)
	# weights3: hidden2 -> output (8 x 6)
	weights3 = _random_matrix(hidden2_size, output_size)

func _random_matrix(rows: int, cols: int) -> Array:
	# Creates a 2D array of small random floats between -0.5 and 0.5
	var matrix = []
	for i in rows:
		var row = []
		for j in cols:
			row.append(randf_range(-0.5, 0.5))
		matrix.append(row)
	return matrix

func _relu(x: float) -> float:
	# Activation function - returns x if positive, 0 otherwise
	return max(0.0, x)

func _matmul(inputs: Array, weights: Array) -> Array:
	# Multiplies a 1D input array by a 2D weight matrix
	var output = []
	for j in weights[0].size():
		var sum = 0.0
		for i in inputs.size():
			sum += inputs[i] * weights[i][j]
		output.append(sum)
	return output

func forward(input: Array) -> Array:
	# Pass input through hidden layer 1 with ReLU
	var h1 = _matmul(input, weights1)
	for i in h1.size():
		h1[i] = _relu(h1[i])
	# Pass through hidden layer 2 with ReLU
	var h2 = _matmul(h1, weights2)
	for i in h2.size():
		h2[i] = _relu(h2[i])
	# Output layer - no activation, raw Q values
	var output = _matmul(h2, weights3)
	return output

func choose_action(state: Array) -> int:
	# Epsilon-greedy: explore randomly or exploit best known action
	if randf() < epsilon:
		return randi() % output_size  # random action
	var q_values = forward(state)
	# Pick the action with the highest Q value
	var best_action = 0
	var best_value = q_values[0]
	for i in range(1, q_values.size()):
		if q_values[i] > best_value:
			best_value = q_values[i]
			best_action = i
	return best_action

func get_reward(damage_taken: float, player_died: bool) -> float:
	if player_died:
		return -1.0   # worst outcome
	if damage_taken <= 0.0:
		return 1.0    # perfect clear
	if damage_taken < 0.3:
		return 0.5    # cleared with minor damage
	return 0.1        # cleared but took significant damage

func train(state: Array, action: int, reward: float, next_state: Array) -> void:
	# Get current Q values for this state
	var q_values = forward(state)
	
	# Get Q values for next state to calculate target
	var next_q_values = forward(next_state)
	
	# Find best next Q value
	var max_next_q = next_q_values[0]
	for i in range(1, next_q_values.size()):
		if next_q_values[i] > max_next_q:
			max_next_q = next_q_values[i]
			
	# Bellman equation: what the Q value SHOULD have been
	var target_q = reward + gamma * max_next_q
	
	# Calculate error only for the action that was taken
	var error = target_q - q_values[action]
	
	# Backpropagate and update weights3 (output layer)
	var h1 = _matmul(state, weights1)
	for i in h1.size():
		h1[i] = _relu(h1[i])
	var h2 = _matmul(h1, weights2)
	for i in h2.size():
		h2[i] = _relu(h2[i])
		
	 # Update weights3 using gradient descent
	for i in weights3.size():
		weights3[i][action] += alpha * error * h2[i]
	
	# Decay epsilon so the network explores less over time
	epsilon = max(epsilon_min, epsilon * epsilon_decay)
