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
@export var speed = 150.0	#movement speed is definetly up for change
@export var attack_speed: float = 0.8
@export var max_health := 100
var health := max_health
var curr_state: State = State.IDLE
var prev_state: State = State.IDLE
var is_dead: bool = false
var is_attack: bool = false
var is_hurt: bool = false

var cardinal_direct : Vector2 = Vector2.DOWN
var move_direct: Vector2 = Vector2.ZERO
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playbk: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var state_mach : PlayerStateMachine

func _ready() -> void:
	anim_tree = $AnimationTree
	anim_tree.set_active(true)
	anim_playbk = anim_tree.get("parameters/playback")
	_enter_state(State.IDLE)


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
	update_anim()

#Input & movement

func movement_loop() -> void:
	if is_attack or is_hurt:
		velocity = Vector2.ZERO
		return
	
	var input = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	
	velocity = input * speed
	
	if input != Vector2.ZERO:
		cardinal_direct = input

#State Resolution

func set_state() -> void:
	# Priority: death > hurt > attack > move > idle
	if is_dead:
		_enter_state(State.DEATH)
		return
	if is_hurt:
		_enter_state(State.HURT)
		return
	if is_attack:
		return
	var moving = velocity.length() > 0
	
	if moving:
		_resolve_move_state()
	else:
		_resolve_idle_state()

func _resolve_move_state() -> void:
	# Determine walk direction based on input
	var input = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
		)

	if abs(input.y) > abs(input.x):
		if input.y < 0:
			_enter_state(State.WALK_UP)
		else:
			_enter_state(State.WALK)       # Walk down = default forward
	else:
		_enter_state(State.WALK_RIGHT)     # Sprite flip handles left

func _resolve_idle_state() -> void:
	# Mirror last facing direction into idle state
	if abs(facing_direction.y) > abs(facing_direction.x):
		if facing_direction.y < 0:
			_enter_state(State.IDLE_UP)
		else:
			_enter_state(State.IDLE)
	else:
		_enter_state(State.IDLE_RIGHT)

#State Enter

func _enter_state(new_state: State) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state

#Animation

func _update_anim() -> void:
	# Flip sprite for left-facing
	if facing_direction.x < 0:
		$Plain.flip_h = true
	elif facing_direction.x > 0:
		$Plain.flip_h = false
	
	var anim_name: String = _state_to_anim(current_state)
	anim_state.travel(anim_name)

func _state_to_anim(state: State) -> String:
	match state:
		State.IDLE:        return "Idle"
		State.IDLE_UP:     return "Idle_Up"
		State.IDLE_RIGHT:  return "Idle_Right"
		State.WALK:        return "Walk"
		State.WALK_UP:     return "Walk_Up"
		State.WALK_RIGHT:  return "Walk_Right"
		State.ATTACK_SW:   return "Attack_SW"
		State.ATTACK_SP:   return "Attack_SP"
		State.HURT:        return "Hurt"
		State.DEATH:       return "Death"
		return "Idle"

#API
func attack_sw() -> void:
	if is_dead or is_hurt or is_attacking:
		return
	is_attacking = true
	_enter_state(State.ATTACK_SW)

func attack_sp() -> void:
	if is_dead or is_hurt or is_attacking:
		return
	is_attacking = true
	_enter_state(State.ATTACK_SP)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		health = 0
		is_dead = true
	else:
		is_hurt = true

#Animation signals

func _on_animation_finished(anim_name: String) -> void:
	match anim_name:
		"Attack_SW", "Attack_SP":
			is_attacking = false
			_enter_state(State.IDLE)
		
		"Hurt":
			is_hurt = false
			# Return to whatever the player was doing
			_enter_state(State.IDLE)
		"Death":
			# Freeze on last frame — emit signal, load death screen, etc.
			set_physics_process(false)
