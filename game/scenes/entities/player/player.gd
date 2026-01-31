extends CharacterBody2D


const SPEED = 300.0
# const JUMP_VELOCITY = -400.0 /not entirely sure why "jump" is here, but I'm commenting it out for now

var move_direct: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
	
	#function call for movement
	movement_loop()

func movement_loop() -> void:
	#gives the move_direct definitions for both the x & y axis
	move_direct.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direct.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	#creates the motion of the character
	var motion: Vector2 = move_direct.normalized() * SPEED
	set_velocity(motion)
	move_and_slide()
