extends Node

signal dialogue_received(text, sender)

var can_request := true

# -------------------------
# REQUEST (MOCK AI)
# -------------------------
func request_dialogue(data: Dictionary, sender: Node):
	if not can_request:
		return
	
	can_request = false

	var text := _generate_dialogue(data)

	# simulate small delay (feels more real)
	await get_tree().create_timer(0.1).timeout

	emit_signal("dialogue_received", text, sender)

	can_request = true


# -------------------------
# MOCK AI LOGIC
# -------------------------
func _generate_dialogue(data: Dictionary) -> String:
	
	# 🎭 Enemy dialogue
	if data.has("enemy_type"):
		var enemy_type = data["enemy_type"]
		var state = data.get("enemy_state", "taunt")

		var lines = {
			"skeleton": {
				"taunt": [
					"Your bones will rattle like mine!",
					"Join the eternal grave...",
					"I sense your fear..."
				],
				"fear": [
					"I... cannot fall again!",
					"Stay back!",
					"This isn't over..."
				]
			},

			# 🧛 VAMPIRE DIALOGUE
			"vampire": {
				"taunt": [
					"Your blood calls to me...",
					"You cannot escape the night.",
					"I have waited centuries for this...",
					"Such warmth... I will savor it.",
					"You look delicious."
				],
				"fear": [
					"This light... it burns!",
					"No... I will not fall again!",
					"You are stronger than you look...",
					"I underestimated you...",
					"This cannot be happening..."
				],
				"attack": [
					"Bleed for me!",
					"Your life is mine!",
					"I will drain you dry!",
					"Struggle... it makes it sweeter."
				]
			}
		}

		if lines.has(enemy_type) and lines[enemy_type].has(state):
			return lines[enemy_type][state].pick_random()

		return "I will destroy you!"

	# 🧠 Player state dialogue
	if data.get("health", 100) < 30:
		return [
			"You are fading fast...",
			"Your strength is leaving you...",
			"One more hit could end you..."
		].pick_random()

	if data.get("enemy_count", 0) > 2:
		return [
			"They surround you.",
			"Too many enemies closing in!",
			"You are overwhelmed!"
		].pick_random()

	if data.get("enemy_count", 0) == 0:
		return [
			"A moment of peace.",
			"Silence fills the room.",
			"For now, you are safe..."
		].pick_random()

	return "The dungeon is quiet..."
