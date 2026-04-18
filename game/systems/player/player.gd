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
var last_dir:= ""
var attack_type = "" #sw or sp

var cardinal_direct : Vector2 = Vector2.DOWN

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_enter_state(State.IDLE)
	add_to_group("player")
	print("READY RUNNING")
	print("Slots found: ", slots.size())
	print("Panel path check: ", get_node_or_null("/root/main_scene/CanvasLayer/Panel"))
	$Hurtbox.area_entered.connect(on_hit)

@onready var slots = get_tree().get_root().get_node("/root/main_scene/CanvasLayer/Panel/GridContainer").get_children()

func add_item(item: Item):
	# Check if item already exists in inventory
	for existing in inventory:
		if existing.item_name == item.item_name:
			if existing.quantity < existing.max_stack:
				existing.quantity += 1
				update_inventory_ui()
				return
	# No existing stack found, add as new slot
	if inventory.size() < max_slots:
		inventory.append(item)
		update_inventory_ui()
	else:
		print("Inventory full!")

func remove_item(item: Item):
	inventory.erase(item)
	update_inventory_ui()

func update_inventory_ui():
	for i in range(slots.size()):
		var slot = slots[i]
		var label = slot.get_node_or_null("Label")
		if i < inventory.size():
			slot.texture = inventory[i].icon
			slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if label:
				label.text = str(inventory[i].quantity) if inventory[i].quantity > 1 else ""
		else:
			slot.texture = null
			if label:
				label.text = ""

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

func _play_anim(base: String, dir: String = ""):
	var anim_name := _state_to_anim(base + dir)
	if anim.animation != anim_name:
		anim.play(anim_name)

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

func hit_sw_attack():
	$Hitbox/CollisionShape2D.disabled = false
	await get_tree().create_timer(0.2).timeout
	$Hitbox/CollisionShape2D.disabled = true

func on_hit(area: Area2D):
	if area.is_in_group("hitbox"):
		take_damage(area.damage)

func add_coins(amount: int):
	# For now just print, add a coin counter var if needed
	print("Collected ", amount, " coin(s)")
