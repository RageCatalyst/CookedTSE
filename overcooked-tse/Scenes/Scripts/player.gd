extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var held_item : Node3D = null

@onready var hold_position = $HoldPosition

@onready var placement_preview = $PlacementPreview
var preview_instance: Node3D = null
var preview_scene = preload("res://Scenes/Food/PlacementPreview.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if held_item:
			drop_item()

	if held_item:
		var countertop = find_nearby_countertop()
		if countertop:
			var snap_point = countertop.get_node("SnapPoint")
			
			# Spawn the preview if not already
			if not preview_instance:
				preview_instance = preview_scene.instantiate()
				placement_preview.add_child(preview_instance)
				preview_instance.set_ingredient_type(held_item.name)
			
			# Align preview with snap point
			preview_instance.global_transform = snap_point.global_transform
		else:
			# Hide or remove preview if not near
			if preview_instance:
				preview_instance.queue_free()
				preview_instance = null
	else:
		# No held item? remove preview
		if preview_instance:
			preview_instance.queue_free()
			preview_instance = null


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

	if item_node is RigidBody3D:
		item_node.freeze = true  # <- This is key

func drop_item():
	if held_item:
		var dropped_item = held_item
		held_item = null

		print("player dropped: " + dropped_item.name)
		var countertop = find_nearby_countertop()
		if countertop:
			var snap_point = countertop.get_node("SnapPoint")
			dropped_item.reparent(countertop)
			dropped_item.global_transform = snap_point.global_transform

			# Optional: disable physics so it stays perfectly placed
			if dropped_item is RigidBody3D:
				dropped_item.freeze = true
		else:
			# Drop normally in front of player
			dropped_item.reparent(get_parent())
			dropped_item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5

			if dropped_item is RigidBody3D:
				dropped_item.freeze = false
				dropped_item.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))

func find_nearby_countertop():
	var radius = 5.0  # Change as needed
	var closest_countertop = null
	var closest_distance = radius

	for obj in get_tree().get_nodes_in_group("countertops"):
		var distance = obj.global_transform.origin.distance_to(global_transform.origin)
		print("Checking countertop: ", obj.name, " Distance: ", distance)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_countertop = obj

	if closest_countertop:
		print("Found nearby countertop: ", closest_countertop.name)
	else:
		print("No nearby countertops found within radius: ", radius)

	return closest_countertop
