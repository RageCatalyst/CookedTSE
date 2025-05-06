extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var held_item : Node3D = null

@onready var hold_position = $HoldPosition

@onready var interaction_area = $InteractionArea

var last_countertop_state: bool = false
var check_countertop_timer: float = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _process(delta: float) -> void:
	check_countertop_timer -= delta
	if Input.is_action_just_pressed("interact"):
		if held_item:
			drop_item()
			
	if check_countertop_timer <=0:
		check_countertop_timer = 5.0
		var near_countertop = get_near_countertop()
		var is_near = near_countertop != null
		if is_near != last_countertop_state:
			last_countertop_state = is_near
			if is_near:
				print("player is in range of countertop")
			else:
				print("no countertop detected")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
var last_placed_countertop : Node3D = null
func pick_up_item(item_node):
	if held_item == null:
		held_item = item_node
		attach_item_to_hand(item_node)
	print("player is holding: " + held_item.name)
	
	if last_placed_countertop:
		print("placed object on the countertop", last_placed_countertop.placed_object)
		if last_placed_countertop.placed_object == item_node:
			print("removing object from countertop")
			last_placed_countertop.remove_object()
	else:
		print("no countertop whereitem was placed")


func attach_item_to_hand(item_node):
	item_node.reparent(hold_position)
	item_node.position = Vector3.ZERO
	item_node.rotation_degrees = Vector3.ZERO
	item_node.set_physics_process(false)

func get_near_countertop() -> Node3D:
	var overlapping_areas = interaction_area.get_overlapping_areas()
	print("detected areas: ", overlapping_areas)
	for area in overlapping_areas:
		var parent = area.get_parent()
		print("checking area:", area.name)
		print("Parent of area: ", area.get_parent().name)
		if parent.is_in_group("Countertop") or parent.has_method("can_place_object"):
			print("found countertop")
			return parent
			
	print("no countertop found")
	return null

	
	for area in overlapping_areas:
		print("area name:", area.name)
		print("parent name:", area.get_parent().name)
		if area.get_parent().is_in_group("Countertop"):
			print("found countertop")
			return area.get_parent()
	print("no countertop found")
	return null



func drop_item():
	if held_item:
		var dropped_item = held_item
		held_item = null  # Clear the player's held item
		
		#check if the player is near a countertop
		var near_countertop = get_near_countertop()
		if near_countertop:
			print("near countertop (drop item test)")
			if near_countertop.has_method("can_place_object") and near_countertop.has_method("place_object"):
				print("countertop has placement functions")
				if near_countertop.can_place_object():
					print("placing object on countertop")
					near_countertop.place_object(dropped_item)
					last_placed_countertop = near_countertop
					return
				else:
					print("Countertop is full")
			else:
				print("Detected object is not a countertop")
	
		# Reparent the item back to the world
		
		dropped_item.reparent(get_parent())
		dropped_item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5  # Drop in front
		print("dropped item on the floor")
		# Ensure the object has a RigidBody3D and re-enable physics
		var rigid_body = dropped_item as RigidBody3D
		if rigid_body:
			rigid_body.freeze = false  # Unfreeze physics
			rigid_body.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))  # Add a small drop force
