class_name Player extends CharacterBody2D

#Will allow for the change between player states
enum State{
	IDLE,
	IDLE_UP,
	IDLE_RIGHT,
	WALK,
	WALK_UP,
	WALK_RIGHT,
	ATTACK_SW,
	ATTACK_SP,
	HURT,
	DEATH
}

#var state: State = State.IDLE

#stats
var inventory: Array[Item] = []
var max_slots: int = 5

@export var speed : float = 150.0	#movement speed is definetly up for change
@export var attack_speed: float = 0.8
@export var max_health : int = 100
var health : int = max_health
var curr_state: State = State.IDLE
var prev_state: State = State.IDLE
var is_dead: bool = false
var is_attack: bool = false
var is_hurt: bool = false

var cardinal_direct : Vector2 = Vector2.DOWN

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_enter_state(State.IDLE)
	add_to_group("player")
	print("READY RUNNING")
	print("Slots found: ", slots.size())
	print("Panel path check: ", get_node_or_null("/root/main_scene/CanvasLayer/Panel"))
	
	# Create a test item
	var item = Item.new()
	item.name = "Potion"
	item.icon = preload("res://assets/items_&_traps/flasks/flasks_4_1.png") # adjust path if needed

	# Add it to inventory
	add_item(item)

@onready var slots = get_tree().get_root().get_node("/root/main_scene/CanvasLayer/Panel/GridContainer").get_children()

func add_item(item: Item):
	if inventory.size() < max_slots:
		inventory.append(item)
		print(item.name + " added!")
		update_inventory_ui()
	else:
		print("Inventory full!")

func remove_item(item: Item):
	inventory.erase(item)
	update_inventory_ui()

func update_inventory_ui():
	print("Slots size: ", slots.size())
	print("Inventory size: ", inventory.size())
	for i in range(slots.size()):
		if i < inventory.size():
			slots[i].texture = inventory[i].icon
			slots[i].expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			slots[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			print("Slot ", i, " | visible: ", slots[i].visible, " | size: ", slots[i].size, " | global_pos: ", slots[i].global_position)
		else:
			slots[i].texture = null

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	movement_loop()
	move_and_slide()
	
	if Input.is_action_just_pressed("attack_sw"):
		attack_sw()
	elif Input.is_action_just_pressed("attack_sp"):
		attack_sp()
		
	set_state()
	_update_anim()

#Input & movement
func movement_loop() -> void:
	if is_attack or is_hurt:
		velocity = Vector2.ZERO
		return
	
	var raw := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	)

	# Avoids zero-vector issues
	var input := raw.normalized() if raw.length() > 0 else Vector2.ZERO

	velocity = input * speed

	if input != Vector2.ZERO:
		cardinal_direct = input

#State Resolution
func set_state() -> void:
	# If both flags are set, hurt takes priority and cancels attack
	if is_hurt and is_attack:
		is_attack = false

	# Priority: death > hurt > attack > move > idle
	if is_dead:
		_enter_state(State.DEATH)
		return
	if is_hurt:
		_enter_state(State.HURT)
		return
	if is_attack:
		return
	if velocity.length() > 0:
		_resolve_move_state()
	else:
		_resolve_idle_state()

func _resolve_move_state() -> void:
	# Determine walk direction based on input
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
		_enter_state(State.WALK_RIGHT) # Srpite flip handles left

func _resolve_idle_state() -> void:
	# Mirror last facing direction into idle state
	if abs(cardinal_direct.y) > abs(cardinal_direct.x):
		if cardinal_direct.y < 0:
			_enter_state(State.IDLE_UP)
		else:
			_enter_state(State.IDLE)
	else:
		_enter_state(State.IDLE_RIGHT)

#State Enter
func _enter_state(new_state: State) -> void:
	if new_state == curr_state:
		return
	prev_state = curr_state
	curr_state = new_state

#Animation
func _update_anim() -> void:
	# Flip sprite for left-facing
	if cardinal_direct.x < 0:
		$Plain.flip_h = true
	elif cardinal_direct.x > 0:
		$Plain.flip_h = false
	
	var anim_name = _state_to_anim(curr_state)
	# Only restart if it's a different animation
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func _state_to_anim(state: State) -> String:
	match state:
		State.IDLE:        return "idle"
		State.IDLE_UP:     return "idle_up"
		State.IDLE_RIGHT:  return "idle_right"
		State.WALK:        return "walk"
		State.WALK_UP:     return "walk_up"
		State.WALK_RIGHT:  return "walk_right"
		State.ATTACK_SW:   return "attack_sw"
		State.ATTACK_SP:   return "attack_sp"
		State.HURT:        return "hurt"
		State.DEATH:       return "death"
		_:                 return "idle"

#API
func attack_sw() -> void:
	if is_dead or is_hurt or is_attack:
		return
	is_attack = true
	_enter_state(State.ATTACK_SW)

func attack_sp() -> void:
	if is_dead or is_hurt or is_attack:
		return
	is_attack = true
	_enter_state(State.ATTACK_SP)

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
	else:
		is_hurt = true

#Animation signals
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
			# Return to whatever the player was doing
			_enter_state(State.IDLE)
		"death":
			# Freeze on last frame — emit signal, load death screen, etc.
			set_physics_process(false)

func add_coins(amount: int):
	# For now just print, add a coin counter var if needed
	print("Collected ", amount, " coin(s)")
