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
	ATTACK_SP,
	HURT,
	DEATH
}

var cardinal_direct : Vector2 = Vector2.DOWN
var move_direct: Vector2 = Vector2.ZERO
var state: State = State.IDLE

@export var speed = 40.0	#movement speed is definetly up for change
@export var max_health := 30
var health := max_health

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playbk: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]

func _physics_process(delta: float) -> void:
	#function call for movement
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
	
	if state == State.IDLE or State.WALK_RIGHT:
		if move_direct.x < -0.01:
			$Plain.flip_h = true
		elif move_direct.x > 0.01:
			$Plain.flip_h = false
	
	if motion != Vector2.ZERO and state == State.IDLE:
		state = State.WALK
		update_anim()
	elif motion == Vector2.ZERO and state == State.WALK:
		state = State.IDLE
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
	var new_state : State = State.IDLE if move_direct == Vector2.ZERO else State.WALK
	if new_state == state:
		return false
	return true

func update_anim() -> void:
	match state:
		State.IDLE:
			anim_playbk.travel("idle")
		State.WALK:
			anim_playbk.travel("walk")
		State.ATTACK_SW:
			anim_playbk.travel("attack_sw")

func anim_direct() -> String:
	if cardinal_direct == Vector2.DOWN:
		return "down"
	elif cardinal_direct == Vector2.UP:
		return "up"
	else:
		return "right"
