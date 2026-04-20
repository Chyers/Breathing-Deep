extends Node
class_name EncounterManager

var dqn: DQN
var telemetry: Telemetry
var _current_state: Array = []
var _last_action: int = -1
var last_action: int = -1

const skeleton_scene = preload("res://scenes/entities/enemies/skeleton.tscn")
const boss_scene = preload("res://scenes/entities/enemies/vampire.tscn")

func _ready() -> void:
	dqn = DQN.new()       # _init() auto-loads saved weights if they exist
	telemetry = Telemetry.new()
	add_child(telemetry)

# Encounter lifecycle

# Called at the start of each room.
# floor_scalar: normalized floor depth [0, 1]
# hp_ratio:     player current HP / max HP [0, 1]
func start_encounter(floor_scalar: float, hp_ratio: float) -> Array:
	telemetry.start_room()
	_current_state = telemetry.get_state_vector(floor_scalar, hp_ratio)
	_last_action = dqn.choose_action(_current_state)
	last_action = _last_action
	print("Encounter type chosen: %d" % _last_action)
	return _get_enemy_scenes(_last_action)

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

# Stat profiles per encounter type
const PROFILES = {
	"SWARM": {
		"speed": 55, "max_health": 10, "attack_damage": 5,
		"attack_cooldown": 1.0, "hit_offset": 10.0,
		"points": 10
	},
	"BRUISER": {
		"speed": 25, "max_health": 60, "attack_damage": 20,
		"attack_cooldown": 2.0, "hit_offset": 12.0, 
		"points": 50
	},
	"FLANKER": {
		"speed": 65, "max_health": 20, "attack_damage": 8,
		"attack_cooldown": 0.9, "hit_offset": 10.0,
		"points": 25
	},
	"ELITE": {
		"speed": 40, "max_health": 80, "attack_damage": 25,
		"attack_cooldown": 1.5, "hit_offset": 14.0, 
		"points": 100
	},
	"MIXED": {
		"speed": 40, "max_health": 30, "attack_damage": 10,
		"attack_cooldown": 1.2, "hit_offset": 10.0, 
		"points": 30
	},
}

const BOSS_PROFILES = {
	"EASY": {
		"speed": 35, "max_health": 120, "attack_damage": 15,
		"attack_cooldown": 1.8, "hit_offset": 12.0,
		"point_value": 300,
		"phase2_threshold": 0.5
	},
	"NORMAL": {
		"speed": 45, "max_health": 180, "attack_damage": 22,
		"attack_cooldown": 1.4, "hit_offset": 13.0,
		"point_value": 500,
		"phase2_threshold": 0.5
	},
	"HARD": {
		"speed": 55, "max_health": 240, "attack_damage": 30,
		"attack_cooldown": 1.0, "hit_offset": 14.0,
		"point_value": 750,
		"phase2_threshold": 0.5
	},
}

func _get_enemy_scenes(encounter_type: int) -> Array:
	var type_name: String = EncounterTypes.EncounterType.keys()[encounter_type]
	print("Encounter selected: %s" % type_name)
	
	match encounter_type:
		EncounterTypes.EncounterType.SWARM:
			print("Spawning: 4x SWARM skeletons (fast, low HP, low damage)")
			return _make_enemies("SWARM", 4)
		EncounterTypes.EncounterType.BRUISER:
			print("Spawning: 1x BRUISER skeleton (slow, high HP, high damage)")
			return _make_enemies("BRUISER", 1)
		EncounterTypes.EncounterType.FLANKER:
			print("Spawning: 2x FLANKER skeletons (quick, low damage)")
			return _make_enemies("FLANKER", 2)
		EncounterTypes.EncounterType.ELITE:
			print("Spawning: 1x ELITE skeleton (balanced, very high HP and damage)")
			return _make_enemies("ELITE", 1)
		EncounterTypes.EncounterType.MIXED:
			print("Spawning: 1x BRUISER + 2x SWARM skeletons")
			return _make_enemies("BRUISER", 1) + _make_enemies("SWARM", 2)
		_:
			print("Spawning: fallback 2x MIXED skeletons")
			return _make_enemies("MIXED", 2)

func _make_enemies(profile_key: String, count: int) -> Array:
	var enemies := []
	var profile: Dictionary = PROFILES[profile_key]
	print("  Profile [%s]: speed=%d hp=%d dmg=%d cooldown=%.1f" % [
		profile_key,
		profile["speed"],
		profile["max_health"],
		profile["attack_damage"],
		profile["attack_cooldown"]
	])
	for i in count:
		var enemy = skeleton_scene.instantiate()
		if enemy.has_method("setup"):
			enemy.setup(profile)
		enemies.append(enemy)
	return enemies

func get_boss_profile() -> Dictionary:
	# Pulls the metrics the DQN already tracks
	var avg_damage: float = telemetry.get_avg_recent_damage_normalized()   # normalized [0,1]
	var avg_time_delta: float = telemetry.get_avg_clear_time_delta()     # in seconds

	# Player is struggling: low damage dealt, slow clears, or died
	if avg_damage > 0.5 or telemetry.get_recent_death_rate() > 0:
		print("Boss difficulty: EASY (player struggled)")
		return BOSS_PROFILES["EASY"]

	# Player is breezing through: fast clears, low damage taken
	if avg_damage < 0.2 and avg_time_delta < -0.2:
		print("Boss difficulty: HARD (player is dominating)")
		return BOSS_PROFILES["HARD"]

	print("Boss difficulty: NORMAL")
	return BOSS_PROFILES["NORMAL"]
	
func spawn_boss() -> Array:
	var profile := get_boss_profile()
	var boss = boss_scene.instantiate()
	if boss.has_method("setup"):
		boss.setup(profile)
	return [boss]

# Persistence

# Call at natural checkpoints: between floors, on quit, on game-over screen, etc.
func save_session() -> void:
	dqn.save_weights()
