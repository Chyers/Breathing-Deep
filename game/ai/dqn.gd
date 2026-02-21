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
