class_name Player
extends CharacterBody2D

#Will allow for the change between player states
enum State{
	IDLE,
	IDLE_UP,
	IDLE_RIGHT,
	WALK,
	WALK_UP,
	WALK_RIGHT,
	ATTACK_SW,
	ATTACK_SW_UP,
	ATTACK_SW_RIGHT,
	ATTACK_SP,
	ATTACK_SP_UP,
	ATTACK_SP_RIGHT,
	HURT,
	HURT_UP,
	HURT_RIGHT,
	DEATH,
	DEATH_UP,
	DEATH_RIGHT
}

# Stats / State
var inventory: Array[Item] = []
var max_slots: int = 5

@export var speed: float = 150.0
@export var attack_speed: float = 0.8
@export var max_health: int = 100

var health: int = max_health
var curr_state: State = State.IDLE
var prev_state: State = State.IDLE
var is_dead: bool = false
var is_attack: bool = false
var is_hurt: bool = false
var last_dir:= ""
var attack_type = "" #sw or sp

var cardinal_direct: Vector2 = Vector2.DOWN

# Inventory / Buffs
var selected_slot: int = -1
var damage_multiplier: float = 1.0
var buff_timer: float = 0.0
var item_cooldowns: Dictionary = {}
var health_cooldown: float = 5.0
var buff_cooldown: float = 15.0

# Node References
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var slots = get_tree().current_scene.get_node("CanvasLayer/Panel/GridContainer").get_children()
@onready var player_hitbox: CollisionShape2D = $Hitbox/CollisionShape2D

# Ready
func _ready() -> void:
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_to_group("player")
	_enter_state(State.IDLE)
	for i in slots.size():
		var slot = slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(i))

# Inventory
func add_item(item: Item) -> void:
	for existing in inventory:
		if existing.item_name == item.item_name and existing.quantity < existing.max_stack:
			existing.quantity += 1
			update_inventory_ui()
			return

	if inventory.size() < max_slots:
		inventory.append(item)
		update_inventory_ui()
	else:
		print("Inventory full!")

func remove_item(item: Item) -> void:
	inventory.erase(item)
	update_inventory_ui()

func update_inventory_ui() -> void:
	for i in slots.size():
		var slot = slots[i]
		var label = slot.get_node_or_null("Label")

		if i < inventory.size():
			var item = inventory[i]
			slot.texture = item.icon
			slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if label:
				label.text = str(item.quantity) if item.quantity > 1 else ""
		else:
			slot.texture = null
			if label:
				label.text = ""

func _refresh_slot_highlight() -> void:
	for i in slots.size():
		slots[i].modulate = Color(1.0, 0.85, 0.2) if i == selected_slot else Color(1, 1, 1)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		selected_slot = index if index < inventory.size() else -1
		_refresh_slot_highlight()

# Item Usage
func use_selected_item() -> void:
	if selected_slot < 0 or selected_slot >= inventory.size():
		print("No item selected.")
		return

	var item: Item = inventory[selected_slot]

	if item_cooldowns.has(item.item_type):
		var remaining : float = snapped(item_cooldowns[item.item_type], 0.1)
		return

	match item.item_type:
		Item.Type.HEALTH:
			var heal := int(max_health * 0.30)
			health = min(health + heal, max_health)
			print("Used Health Potion:", health, "/", max_health)
			item_cooldowns[Item.Type.HEALTH] = health_cooldown

		Item.Type.BUFF:
			damage_multiplier = 1.20
			buff_timer = 10.0
			print("Buff active (+20% damage)")
			item_cooldowns[Item.Type.BUFF] = buff_cooldown

		_:
			print("No effect.")
			return

	# Consume
	item.quantity -= 1
	if item.quantity <= 0:
		inventory.remove_at(selected_slot)
		selected_slot = -1

	update_inventory_ui()
	_refresh_slot_highlight()

# Physics Loop
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_buff(delta)
	movement_loop()
	move_and_slide()

	_handle_input()
	set_state()
	_update_anim()

func _update_buff(delta: float) -> void:
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			damage_multiplier = 1.0
			buff_timer = 0.0
	
	for type in item_cooldowns.keys():
		item_cooldowns[type] -= delta
		if item_cooldowns[type] <= 0.0:
			item_cooldowns.erase(type)

# Input
func _handle_input() -> void:
	if Input.is_action_just_pressed("attack_sw"):
		attack_sw()
	elif Input.is_action_just_pressed("attack_sp"):
		attack_sp()
		
	if Input.is_action_just_pressed("use_item"):
		use_selected_item()

	if Input.is_action_just_pressed("ui_right"):
		selected_slot = min(selected_slot + 1, inventory.size() - 1)
		_refresh_slot_highlight()
	elif Input.is_action_just_pressed("ui_left"):
		selected_slot = max(selected_slot - 1, 0)
		_refresh_slot_highlight()

#Input & movement


func get_dir_suffix() -> String:
	if velocity.y < 0:
		$Plain.flip_h = false
		last_dir = "_UP"
		return "_UP"
	if velocity.x != 0:
		$Plain.flip_h = velocity.x < 0   # flip RIGHT anim for left movement
		last_dir = "_RIGHT"
		return "_RIGHT"
	$Plain.flip_h = false
	last_dir = ""
	return ""

# Movement
func movement_loop() -> void:
	if is_attack or is_hurt:
		velocity = Vector2.ZERO
		return

	var input := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	).normalized()
	
	# Avoids zero-vector issues
	# var input := raw.normalized() if raw.length() > 0 else Vector2.ZERO

	velocity = input * speed

	if input != Vector2.ZERO:
		cardinal_direct = input

# State Logic
func set_state() -> void:
	if is_hurt:
		is_attack = false

	if is_dead:
		_enter_state(State.DEATH)
	elif is_hurt:
		_enter_state(State.HURT)
	elif is_attack:
		return
	elif velocity.length() > 0:
		_resolve_move_state()
	else:
		_resolve_idle_state()

func _resolve_move_state() -> void:
	var raw := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	)

	if raw == Vector2.ZERO:
		_enter_state(State.IDLE)
		return

	if abs(raw.y) > abs(raw.x):
		_enter_state(State.WALK_UP if raw.y < 0 else State.WALK)
	else:
		_enter_state(State.WALK_RIGHT)

func _resolve_idle_state() -> void:
	if abs(cardinal_direct.y) > abs(cardinal_direct.x):
		_enter_state(State.IDLE_UP if cardinal_direct.y < 0 else State.IDLE)
	else:
		_enter_state(State.IDLE_RIGHT)

func _enter_state(new_state: State) -> void:
	if new_state == curr_state:
		return
	prev_state = curr_state
	curr_state = new_state

# Animation Handling
func _update_anim() -> void:
	$Plain.flip_h = cardinal_direct.x < 0

	var anim := _state_to_anim(State.keys()[curr_state])
	if anim_player.current_animation != anim:
		anim_player.play(anim)

func _state_to_anim(state: String) -> String:
	match state:
		"IDLE":        return "idle"
		"IDLE_UP":     return "idle_up"
		"IDLE_RIGHT":  return "idle_right"
		"WALK":        return "walk"
		"WALK_UP":     return "walk_up"
		"WALK_RIGHT":  return "walk_right"
		"ATTACK_SW":   return "attack_sw"
		"ATTACK_SW_RIGHT": return "attack_sw_right"
		"ATTACK_SW_UP": return "attack_sw_up"
		"ATTACK_SP":   return "attack_sp"
		"ATTACK_SP_RIGHT": return "attack_sp_right"
		"ATTACK_SP_UP": return "attack_sp_up"
		"HURT":        return "hurt"
		"HURT_RIGHT":  return "hurt_right"
		"HURT_UP":     return "hurt_up"
		"DEATH":       return "death"
		"DEATH_RIGHT": return "death_right"
		"DEATH_UP":    return "death_up"
		_:                 return "idle"

#func _play_anim(base: String, dir: String = ""):
	#var anim_name := _state_to_anim(base + dir)
	#if anim_player.animation != anim_name:
		#anim_player.play(anim_name)

#API
func attack_sw() -> void:
	if is_dead or is_hurt or is_attack:
		return
	is_attack = true
	_enter_state(State.ATTACK_SW)
	hit_sw_attack()

func attack_sp() -> void:
	if is_dead or is_hurt or is_attack:
		return
	is_attack = true
	_enter_state(State.ATTACK_SP)
	hit_sw_attack()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		health = 0
		is_dead = true
		is_hurt = false
		is_attack = false
		_enter_state(State.DEATH)
		anim_player.play("death")
		await get_tree().create_timer(0.8).timeout
		get_tree().get_first_node_in_group("game_over_menu").show_game_over()
		print("Final score: ", ScoreManager.get_score())
	else:
		is_hurt = true

# Animation Callbacks
func _on_animation_finished(anim_name: String) -> void:
	if is_dead and anim_name != "death":
		return

	match anim_name:
		"attack_sw", "attack_sp":
			is_attack = false
			is_hurt = false
			_enter_state(State.IDLE)

		"hurt":
			is_hurt = false
			is_attack = false
			_enter_state(State.IDLE)

		"death":
			set_physics_process(false)

func hit_sw_attack() -> void:
	if not is_instance_valid(player_hitbox):
		return
	player_hitbox.disabled = false
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(player_hitbox):
		player_hitbox.disabled = true

#func on_hit(area: Area2D):
	#if area.is_in_group("hitbox"):
		#take_damage(area.damage)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			parent.take_damage(10)

func add_coins(amount: int):
	# For now just print, add a coin counter var if needed
	print("Collected ", amount, " coin(s)")
	
