extends CharacterBody3D

const SPEED = 5.0

@export var held_item : Node3D = null
@export var held_item_ingredient_name : String

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
		_handle_placement_preview()
	else:
		_remove_placement_preview()

func _handle_placement_preview():
	var countertop = get_facing_countertop()
	if countertop:
		var snap_point = countertop.get_node_or_null("SnapPoint")
		if snap_point:
			if not preview_instance:
				for group in held_item.get_groups():
					match group:
						"onion":
							held_item_ingredient_name = "onion"
						"tomato":
							held_item_ingredient_name = "tomato"
						"mushroom":
							held_item_ingredient_name = "mushroom"
				if held_item_ingredient_name:
					show_preview(countertop, held_item_ingredient_name)
				else:
					print("No ingredient group found!")
			else:
				# Always update preview position
				preview_instance.global_transform = snap_point.global_transform
				# Ensure preview is parented to the scene root for visibility
				var scene_root = get_tree().current_scene
				if preview_instance.get_parent() != scene_root:
					preview_instance.reparent(scene_root)
				if preview_instance.has_method("set_ingredient_type"):
					preview_instance.set_ingredient_type(held_item_ingredient_name)
			if preview_instance:
				preview_instance.visible = true
			return
	_remove_placement_preview()

func _remove_placement_preview():
	if preview_instance:
		preview_instance.queue_free()
		preview_instance = null

func _physics_process(_delta: float) -> void:
	_handle_movement()
	move_and_slide()

func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction.length() > 0.1:
		facing_direction = direction
		look_at(global_transform.origin + facing_direction, Vector3.UP)

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func is_facing_target(target_node: Node3D, max_angle_degrees := 60.0) -> bool:
	var to_target = (target_node.global_transform.origin - global_transform.origin).normalized()
	var angle = rad_to_deg(facing_direction.angle_to(to_target))
	return angle < max_angle_degrees

func pick_up_item(item_node):
	if held_item == null:
		held_item = item_node
		attach_item_to_hand(item_node)
	if item_node.has_method("clear_countertop"):
		item_node.clear_countertop()
	print("player is holding: " + held_item.name)

func attach_item_to_hand(item_node):
	item_node.reparent(hold_position)
	item_node.position = Vector3.ZERO
	item_node.rotation_degrees = Vector3.ZERO
	if item_node is RigidBody3D:
		item_node.freeze = true

func drop_item():
	if not held_item:
		return
	var dropped_item = held_item
	held_item = null
	print("player dropped: " + dropped_item.name)
	var countertop = get_facing_countertop()
	if countertop and is_facing_target(countertop):
		_snap_item_to_countertop(dropped_item, countertop)
	else:
		_drop_item_in_front(dropped_item)

func _snap_item_to_countertop(item, countertop):
	var snap_point = countertop.get_node_or_null("SnapPoint")
	if snap_point:
		item.reparent(countertop)
		item.global_transform = snap_point.global_transform
		if item is RigidBody3D:
			item.freeze = true
		if item.has_method("set_countertop"):
			item.set_countertop(countertop)
		if item.get_child_count() > 0 and item.get_child(0).has_method("set_countertop"):
			item.get_child(0).set_countertop(countertop)
	else:
		print("SnapPoint not found!")

func _drop_item_in_front(item):
	item.reparent(get_parent())
	item.global_transform.origin = global_transform.origin + transform.basis.z * -1.5
	if item is RigidBody3D:
		item.freeze = false
		item.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2))
	if item.has_method("clear_countertop"):
		item.clear_countertop()

# Returns the countertop directly in front of the player using a RayCast3D node named 'CountertopRaycast'
func get_facing_countertop():
	var raycast = $CountertopRaycast
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("countertops"):
			#print("Countertop found: " + collider.name)
			return collider.get_parent().get_parent()  # Assuming the countertop is a child of the parent node
	return null

func show_preview(countertop: Node3D, ingredient_type: String):
	print("Showing preview for: " + ingredient_type)
	var snap_point = countertop.get_node_or_null("SnapPoint")
	if snap_point:
		if not preview_instance:
			preview_instance = preview_scene.instantiate()
			# Add to scene root for visibility
			get_tree().current_scene.add_child(preview_instance)
		preview_instance.global_transform = snap_point.global_transform
		preview_instance.set_ingredient_type(ingredient_type)
		preview_instance.visible = true
	else:
		print("SnapPoint not found!")
