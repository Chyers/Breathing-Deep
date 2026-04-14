extends ProgressBar

var player: Node = null

func _ready() -> void:
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		max_value = player.max_health
		value = player.health
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.1, 0.1)  # deep red
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	add_theme_stylebox_override("fill", fill_style)

func _process(_delta: float) -> void:
	if player != null:
		value = player.health
