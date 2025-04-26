extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var held_item : Node3D = null

@onready var hold_position = $HoldPosition

@onready var placement_preview = $PlacementPreview
var preview_scene = preload("res://Scenes/Food/IngredientPreview.tscn")
var preview_instance: Node3D = null

var facing_direction: Vector3 = Vector3.FORWARD

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
			var _snap_point = countertop.get_node("SnapPoint")
			
			# Spawn the preview if not already
			if not preview_instance:
				show_preview(countertop, held_item.name)
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

	# Optional debug visualization (commented out until DebugDraw3D is implemented)cvxbfxdcv
	# var from = global_transform.origin
	# var to = from + facing_direction * 2.0
	# DebugDraw3D.draw_line(from, to, Color.BLUE)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()  # Use world space direction

	if direction.length() > 0.1:
		facing_direction = direction
		# Update character's rotation to face the direction using look_at
		look_at(global_transform.origin + facing_direction, Vector3.UP)

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func is_facing_target(target_node: Node3D, max_angle_degrees := 60.0) -> bool:
	var to_target = (target_node.global_transform.origin - global_transform.origin).normalized()
	var angle = rad_to_deg(facing_direction.angle_to(to_target))
	return angle < max_angle_degrees

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
			if is_facing_target(countertop):
				var snap_point = countertop.get_node("SnapPoint")
				dropped_item.reparent(countertop)
				if dropped_item.get_child(0).has_method("set_countertop"):
					print("set countertop to " + countertop.name)
					dropped_item.get_child(0).set_countertop(countertop)
				dropped_item.global_transform = snap_point.global_transform

				# Optional: disable physics so it stays perfectly placed
				if dropped_item is RigidBody3D:
					dropped_item.freeze = true

				# Tell the item which countertop it's on
				if dropped_item.has_method("set_countertop"):
					dropped_item.set_countertop(countertop)
			else:
				# Drop normally in front of player if not facing the target
				print("Target is in range but not facing the right direction. Dropping item.")
				dropped_item.reparent(get_parent())
				dropped_item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5

				if dropped_item is RigidBody3D:
					dropped_item.freeze = false
					dropped_item.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))

				# Clear countertop reference if the item supports it
				if dropped_item.has_method("clear_countertop"):
					dropped_item.clear_countertop()
		else:
			# Drop normally in front of player
			dropped_item.reparent(get_parent())
			dropped_item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5

			if dropped_item is RigidBody3D:
				dropped_item.freeze = false
				dropped_item.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))

			# Clear countertop reference if the item supports it
			if dropped_item.has_method("clear_countertop"):
				dropped_item.clear_countertop()

func find_nearby_countertop():
	var radius = 2.0  # Change as needed
	var closest_countertop = null
	var closest_distance = radius

	for obj in get_tree().get_nodes_in_group("countertops"):
		var distance = obj.global_transform.origin.distance_to(global_transform.origin)
		#print("Checking countertop: ", obj.name, " Distance: ", distance)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_countertop = obj

	#if closest_countertop:
		#print("Found nearby countertop: ", closest_countertop.name)
	#else:
		#print("No nearby countertops found within radius: ", radius)

	return closest_countertop
	
func show_preview(countertop: Node3D, ingredient_type: String):
	var snap_point = countertop.get_node_or_null("SnapPoint")
	if snap_point:
		# Spawn only once
		if not preview_instance:
			preview_instance = preview_scene.instantiate()
			get_parent().add_child(preview_instance)
		
		# Move to snap point
		preview_instance.global_transform = snap_point.global_transform
		
		# Set the mesh/visual
		preview_instance.set_ingredient_type(ingredient_type)
	else:
		print("SnapPoint not found!")
