extends Node2D

@export var min_items: int = 1
@export var max_items: int = 4

var item_scenes = [
	preload("res://scenes/environment/coin.tscn"),
	preload("res://scenes/environment/health.tscn"),
	preload("res://scenes/environment/buff.tscn")
]

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	spawn_items()

func spawn_items():
	var spawn_points = $ItemSpawn.get_children()
	var item_count = randi_range(min_items, max_items)
	
	spawn_points.shuffle()
	
	for i in range(min(item_count, spawn_points.size())):
		var spawn_point = spawn_points[i]
		var item_scene = item_scenes.pick_random()
		var item = item_scene.instantiate()
		
		item.position = spawn_point.position
		add_child(item)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
