extends Node

signal score_changed(value)

var score: int = 0

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)   # 🔥 notify UI
	print("Score: ", score)

func reset_score() -> void:
	score = 0
	score_changed.emit(score)

func get_score() -> int:
	return score
