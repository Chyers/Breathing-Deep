extends Node

func assign_key_drops(enemies: Array[Node]) -> void:
	KeyManager.reset()
	if enemies.size() < 3:
		push_warning("Fewer than 3 enemies — only %d key(s) will drop." % enemies.size())

	var shuffled := enemies.duplicate()
	shuffled.shuffle()
	var count := mini(3, shuffled.size())
	for i in count:
		shuffled[i].set_meta("drops_key", true)
