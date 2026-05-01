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

const STATE_MAP = {
	"IDLE": State.IDLE,
	"IDLE_UP": State.IDLE_UP,
	"IDLE_RIGHT": State.IDLE_RIGHT,
	"WALK": State.WALK,
	"WALK_UP": State.WALK_UP,
	"WALK_RIGHT": State.WALK_RIGHT,
	"ATTACK_SW": State.ATTACK_SW,
	"ATTACK_SW_UP": State.ATTACK_SW_UP,
	"ATTACK_SW_RIGHT": State.ATTACK_SW_RIGHT,
	"ATTACK_SP": State.ATTACK_SP,
	"ATTACK_SP_UP": State.ATTACK_SP_UP,
	"ATTACK_SP_RIGHT": State.ATTACK_SP_RIGHT,
	"HURT": State.HURT,
	"HURT_UP": State.HURT_UP,
	"HURT_RIGHT": State.HURT_RIGHT,
	"DEATH": State.DEATH,
	"DEATH_UP": State.DEATH_UP,
	"DEATH_RIGHT": State.DEATH_RIGHT
}

# Stats / State
var inventory: Array[Item] = []
var max_slots: int = 5

@export var speed: float = 150.0
@export var attack_speed: float = 1.0
@export var max_health: int = 100

var health: int = max_health
var curr_state: State = State.IDLE
var prev_state: State = State.IDLE
var is_dead: bool = false
var is_attack: bool = false
var is_hurt: bool = false
var last_dir:= ""
var attack_type = "" #sw or sp
var is_dashing: bool = false
var dash_speed: float = 75.0
var sp_cooldown_timer: float = 0.0

var cardinal_direct: Vector2 = Vector2.DOWN

# Inventory / Buffs
var selected_slot: int = -1
var damage_multiplier: float = 1.0
var buff_timer: float = 0.0
var item_cooldowns: Dictionary = {}
var health_cooldown: float = 5.0
var buff_cooldown: float = 15.0
var iframe_timer: float = 0.0
var _flash_acc: float = 0.0
var has_spear: bool = false

const REVIVAL_IFRAME_DURATION: float = 2.5
const REVIVAL_FLASH_RATE: float = 12.0
const SP_COOLDOWN: float = 2.0
const DASH_IFRAME_DURATION: float = 0.5


# Node References
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var slots = get_tree().current_scene.get_node("CanvasLayer/Panel/GridContainer").get_children()
@onready var hitbox_down: CollisionShape2D = $Hitbox/CollisionShape2D_Down
@onready var hitbox_up: CollisionShape2D = $Hitbox/CollisionShape2D_Up
@onready var hitbox_side: CollisionShape2D = $Hitbox/CollisionShape2D

# Ready
func _ready() -> void:
	set_collision_mask_value(3, true)
	print("Player mask after fix: ", collision_mask)
	print("Player layer: ", collision_layer)
	print("Player mask: ", collision_mask)
	var dir := get_dir_suffix()
	add_to_group("player")
	_play_anim("IDLE", dir)

	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
  
	for i in slots.size():
		var slot = slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
	
	anim_player.animation_finished.connect(_on_animation_finished)
	
	_disable_all_hitboxes()

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
			damage_multiplier = 3.20
			attack_speed = 1.10
			anim_player.speed_scale = attack_speed
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

func _consume_revival_item(index: int) -> void:
	print("Revival Orb activated!")
	var orb: Item = inventory[index]
	orb.quantity -= 1
	if orb.quantity <= 0:
		inventory.remove_at(index)
		selected_slot = -1
	update_inventory_ui()
	_refresh_slot_highlight()

	is_dead = true
	anim_player.play("death")
	await get_tree().create_timer(0.8).timeout

	is_dead = false
	is_hurt = false
	is_attack = false
	health = int(max_health * 0.5)
	iframe_timer = REVIVAL_IFRAME_DURATION
	_flash_acc = 0.0
	set_physics_process(true)
	_play_anim("idle", last_dir)

# Physics Loop
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if sp_cooldown_timer > 0.0:
		sp_cooldown_timer -= delta
	_update_buff(delta)
	_update_iframes(delta)
	movement_loop()
	move_and_slide()
	_handle_input()
	set_state()

func _update_buff(delta: float) -> void:
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			damage_multiplier = 1.0
			attack_speed = 1.0
			anim_player.speed_scale = 1.0
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
	return last_dir

# Movement
func movement_loop() -> void:
	if is_dashing:
		return
	if is_attack or is_hurt:
		velocity = Vector2.ZERO
		return

	if is_attack or is_hurt:
		velocity = Vector2.ZERO
		return

	var input := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	)

	if input.length() > 0:
		input = input.normalized()
		cardinal_direct = input
		if abs(input.y) > abs(input.x):
			if input.y < 0:
				last_dir = "up"
			else:
				last_dir = ""
		else:
			last_dir = "left" if input.x < 0 else "right"

	velocity = input * speed

# State Logic
func set_state() -> void:
	if is_attack or is_dead:
		return
	var dir := get_dir_suffix()
	if is_hurt:
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
		_resolve_idle_state()
		return
	if abs(raw.y) > abs(raw.x):
		_play_anim("walk", "up" if raw.y < 0 else "")
	else:
		_play_anim("walk", last_dir)

func _resolve_idle_state() -> void:
	if abs(cardinal_direct.y) > abs(cardinal_direct.x):
		_play_anim("idle", "up" if cardinal_direct.y < 0 else "")
	else:
		_play_anim("idle", last_dir)

# Animation Handling
func _update_anim() -> void:
	var dir := get_dir_suffix()
	
	if is_dead:
		_play_anim("DEATH", dir)
	elif is_hurt:
		_play_anim("HURT", dir)
	elif is_attack:
		return

func _play_anim(base: String, dir: String = "") -> void:
	var anim_name := base.to_lower()
	if dir != "":
		anim_name = anim_name + "_" + dir.to_lower()
	$Plain.flip_h = false
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

#API
func _dash_attack() -> void:
	var dash_dir := cardinal_direct.normalized()
	var elapsed := 0.0

	# Enable the correct hitbox for the whole dash
	_disable_all_hitboxes()
	var hitbox := _get_active_hitbox()
	if last_dir == "left":
		hitbox_side.position.x = -abs(hitbox_side.position.x)
	elif last_dir == "right":
		hitbox_side.position.x = abs(hitbox_side.position.x)
	hitbox.disabled = false

	while elapsed < DASH_IFRAME_DURATION and is_attack:
		var delta := get_process_delta_time()
		velocity = dash_dir * dash_speed
		move_and_slide()
		elapsed += delta
		await get_tree().process_frame

	_disable_all_hitboxes()
	is_dashing = false

func attack_sw() -> void:
	if is_dead or is_hurt or is_attack:
		return
	is_attack = true
	_play_anim("attack_sw", last_dir)

func attack_sp() -> void:
	if is_dead or is_hurt or is_attack:
		return
	if not has_spear:
		print("No spear yet!")
		return
	if sp_cooldown_timer > 0.0:
		return
	is_attack = true
	is_dashing = true
	iframe_timer = DASH_IFRAME_DURATION
	sp_cooldown_timer = SP_COOLDOWN
	_play_anim("attack_sp", last_dir)
	_dash_attack()

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	if iframe_timer > 0.0:
		return

	var main_scene = get_tree().get_first_node_in_group("main_scene")
	if main_scene and main_scene.current_room and \
			main_scene.current_room.has_method("record_damage"):
		main_scene.current_room.record_damage(float(amount), float(max_health))

	health -= amount
	is_attack = false

	if health <= 0:
		health = 0

		# Always notify the DQN, even if the player is about to be revived
		if main_scene and main_scene.current_room and \
				main_scene.current_room.has_method("notify_player_died"):
			main_scene.current_room.notify_player_died()

		# Check for revival orb before committing to death
		var revival_index := _find_revival_item()
		if revival_index != -1:
			_consume_revival_item(revival_index)
			return

		# No orb — normal death
		is_dead = true
		is_hurt = false
		is_attack = false
		anim_player.play("death")
		await get_tree().create_timer(0.8).timeout
		get_tree().get_first_node_in_group("game_over_menu").show_game_over()
		print("Final score: ", ScoreManager.get_score())
	else:
		is_hurt = true
		_play_anim("hurt", last_dir)

# Animation Callbacks
func _on_animation_finished(anim_name: String) -> void:
	if is_dead and not anim_name.begins_with("death"):
		return
	if anim_name.begins_with("death"):
		if is_dead:
			set_physics_process(false)
		return
	if anim_name.begins_with("attack"):
		is_attack = false
		is_dashing = false
		_play_anim("idle", last_dir)
	elif anim_name.begins_with("hurt"):
		is_hurt = false
		_play_anim("idle", last_dir)

func hit_attack(duration: float = 0.15) -> void:
	_disable_all_hitboxes()
	var hitbox := _get_active_hitbox()

	if last_dir == "left":
		hitbox_side.position.x = -abs(hitbox_side.position.x)
	elif last_dir == "right":
		hitbox_side.position.x = abs(hitbox_side.position.x)

	hitbox.disabled = false
	
	var adjusted_duration = duration / attack_speed
	
	await get_tree().create_timer(adjusted_duration).timeout
	_disable_all_hitboxes()

func _disable_all_hitboxes() -> void:
	hitbox_down.disabled = true
	hitbox_up.disabled = true
	hitbox_side.disabled = true

func _get_active_hitbox() -> CollisionShape2D:
	match last_dir:
		"up":    return hitbox_up
		"left":  return hitbox_side
		"right": return hitbox_side
		_:       return hitbox_down

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			var damage := int(10 * damage_multiplier)
			parent.take_damage(damage)
	
	if area.is_in_group("chest"):
		var parent = area.get_parent()
		if parent is Chest:
			parent.take_hit(self)

func add_coins(amount: int, icon: Texture2D = null) -> void:
	# Stacks onto existing coin item if one exists
	for item in inventory:
		if item.item_type == Item.Type.COIN:
			item.quantity += amount
			update_inventory_ui()
			return

	# Otherwise creates a new coin stack
	var coin_item := Item.new()
	coin_item.item_name = "Coin"
	coin_item.item_type = Item.Type.COIN
	coin_item.quantity = amount
	coin_item.icon = icon
	coin_item.max_stack = 9999

	add_item(coin_item)

func spend_coins(amount: int) -> bool:
	# Counts total coins across all stacks
	var total_coins: int = 0
	for item in inventory:
		if item.item_type == Item.Type.COIN:
			total_coins += item.quantity

	if total_coins < amount:
		print("Not enough coins! Have: ", total_coins, " Need: ", amount)
		return false

	# Deducts from coin stacks
	var remaining: int = amount
	for item in inventory:
		if item.item_type == Item.Type.COIN and remaining > 0:
			var taken: int = min(item.quantity, remaining)
			item.quantity -= taken
			remaining -= taken

	# Cleans up any empty stacks
	inventory = inventory.filter(func(item): return item.quantity > 0)
	update_inventory_ui()
	return true

func _find_revival_item() -> int:
	for i in inventory.size():
		if inventory[i].item_type == Item.Type.REVIVE:
			return i
	return -1

func _update_iframes(delta: float) -> void:
	if iframe_timer <= 0.0:
		return
	iframe_timer -= delta
	if not is_dashing:
		_flash_acc += delta
		var flash_period := 1.0 / REVIVAL_FLASH_RATE
		if _flash_acc >= flash_period:
			_flash_acc = fmod(_flash_acc, flash_period)
			$Plain.visible = not $Plain.visible
	if iframe_timer <= 0.0:
		$Plain.visible = true
		_flash_acc = 0.0
