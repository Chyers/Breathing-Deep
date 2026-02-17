extends CharacterBody2D

#Will allow for the change between player states
enum State{
	IDLE_DOWN,
	IDLE_UP,
	IDLE_RIGHT,
	WALK_DOWN,
	WALK_UP,
	WALK_RIGHT,
	ATTACK,
	HURT_DOWN,
	DEATH_DOWN
}

var cardinal_direct : Vector2 = Vector2.DOWN
var move_direct: Vector2 = Vector2.ZERO
var state: State = State.IDLE_DOWN

@export var speed = 300.0	#movement speed is definetly up for change
@export var max_health := 30
@export var attack_speed: float = 0.8
var health := max_health

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playbk: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]

func _anim() -> void:
	anim_tree.set_active(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()

func _physics_process(delta: float) -> void:
	#function call for movement
	if not state == State.ATTACK:
		movement_loop()

func movement_loop() -> void:
	#gives the move_direct definitions for both the x & y axis
	move_direct.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direct.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	#creates the motion of the character
	var motion: Vector2 = move_direct.normalized() * speed
	
	if set_state() == true || set_direct() == true:
		update_anim()
	
	set_velocity(motion)
	move_and_slide()
	
	if state == State.IDLE_DOWN or State.WALK_RIGHT:
		if move_direct.x < -0.01:
			$Plain.flip_h = true
		elif move_direct.x > 0.01:
			$Plain.flip_h = false
	
	if motion != Vector2.ZERO and state == State.IDLE_DOWN:
		state = State.WALK_DOWN
		update_anim()
	elif motion == Vector2.ZERO and state == State.WALK_DOWN:
		state = State.IDLE_DOWN
		update_anim()

func set_direct() -> bool:
	var new_direct : Vector2 = cardinal_direct
	if move_direct == Vector2.ZERO:
		return false
	
	if move_direct.y == 0:
		new_direct = Vector2.LEFT if move_direct.x < 0 else Vector2.RIGHT
	elif move_direct.x == 0:
		new_direct = Vector2.UP if move_direct.y < 0 else Vector2.DOWN
		
	if new_direct == cardinal_direct:
		return false
		
	cardinal_direct = new_direct
	return true

func set_state() -> bool:
	var new_state : State = State.IDLE_DOWN if move_direct == Vector2.ZERO else State.WALK_DOWN
	if new_state == state:
		return false
	return true

func update_anim() -> void:
	match state:
		State.IDLE_DOWN:
			anim_playbk.travel("idle")
		State.WALK_DOWN:
			anim_playbk.travel("walk")
		State.ATTACK:
			anim_playbk.travel("attack_sw")

func attack() -> void:
	if state == State.ATTACK:
		return
	state = State.ATTACK
	#mouse clicks to control the attack is temporary
	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()
	#Keep getting "flip_h" errors
	$Plain.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	anim_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	update_anim()
	
	await get_tree().create_timer(attack_speed).timeout
	state = State.IDLE_DOWN

func anim_direct() -> String:
	if cardinal_direct == Vector2.DOWN:
		return "down"
	elif cardinal_direct == Vector2.UP:
		return "up"
	else:
		return "right"
