extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var held_item : Node3D = null

@onready var hold_position = $HoldPosition


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if held_item:
			drop_item()

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

func pick_up_item(item_node):
	if held_item == null:
		held_item = item_node
		attach_item_to_hand(item_node)
	print("player is holding: " + held_item.name)


func attach_item_to_hand(item_node):
	item_node.reparent(hold_position)
	item_node.position = Vector3.ZERO
	item_node.rotation_degrees = Vector3.ZERO
	item_node.set_physics_process(false)

func drop_item():
	if held_item:
		var dropped_item = held_item
		held_item = null  # Clear the player's held item

		# Reparent the item back to the world
		dropped_item.reparent(get_parent())
		dropped_item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5  # Drop in front

		# Ensure the object has a RigidBody3D and re-enable physics
		var rigid_body = dropped_item as RigidBody3D
		if rigid_body:
			rigid_body.freeze = false  # Unfreeze physics
			rigid_body.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))  # Add a small drop force
