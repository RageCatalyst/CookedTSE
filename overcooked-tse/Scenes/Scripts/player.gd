extends CharacterBody3D

const SPEED = 5.0
@export var player_index: int = 0 # Assign this when instantiating the player

@export var held_item : Node3D = null
@export var held_item_ingredient_name : String

@onready var hold_position = $HoldPosition
@onready var interaction_area: Area3D = $InteractionArea # Assign in editor or ensure name matches

# List to track nearby pickup objects
var nearby_pickups: Array[PickupObject] = []
# Reference to the currently highlighted object
var currently_highlighted_pickup: PickupObject = null

@onready var placement_preview = $PlacementPreview
var preview_scene = preload("res://Scenes/Food/IngredientPreview.tscn")
var preview_instance: Node3D = null

var facing_direction: Vector3 = Vector3.FORWARD

func _ready():
	# Connect signals from the player's interaction area
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	else:
		printerr("Player: InteractionArea node not found!")

func _input(event: InputEvent) -> void:
	if player_index == 0 and event.is_action_pressed("exit"):
		get_tree().quit()

func _process(_delta: float) -> void:
	# Handle interaction input
	if Input.is_action_just_pressed("interact_p%d" % player_index):
		if held_item:
			drop_item() # Existing drop logic
		elif currently_highlighted_pickup:
			# Tell the highlighted item it's being picked up
			if currently_highlighted_pickup.has_method("get_picked_up"):
				currently_highlighted_pickup.get_picked_up(self)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update pickup highlighting
	_update_pickup_highlight()

	if held_item:
		_handle_placement_preview()
	else:
		_remove_placement_preview()

	_handle_movement()
	move_and_slide()

# --- Pickup Highlighting Logic ---

func _on_interaction_area_body_entered(body: Node3D):
	# Check if the body is a PickupObject and not already in the list
	if body is PickupObject and not nearby_pickups.has(body):
		nearby_pickups.append(body)

func _on_interaction_area_body_exited(body: Node3D):
	# Remove the body if it's a PickupObject
	if body is PickupObject:
		nearby_pickups.erase(body)
		# If the exited body was the highlighted one, clear the highlight
		if currently_highlighted_pickup == body:
			if currently_highlighted_pickup and currently_highlighted_pickup.has_method("disable_highlight"):
				currently_highlighted_pickup.disable_highlight()
			currently_highlighted_pickup = null

func _update_pickup_highlight():
	var closest_pickup: PickupObject = null
	var min_dist_sq = INF

	# If holding an item, ensure nothing is highlighted
	if held_item:
		if currently_highlighted_pickup:
			if currently_highlighted_pickup.has_method("disable_highlight"):
				currently_highlighted_pickup.disable_highlight()
			currently_highlighted_pickup = null
		return

	# Find the closest pickup object in range
	for pickup in nearby_pickups:
		# Ensure the pickup object is still valid (hasn't been deleted)
		if not is_instance_valid(pickup):
			# Schedule removal for later to avoid modifying array during iteration
			call_deferred("remove_invalid_pickup", pickup)
			continue
		
		var dist_sq = global_position.distance_squared_to(pickup.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_pickup = pickup

	# Update highlighting based on the closest found object
	if closest_pickup != currently_highlighted_pickup:
		# Disable highlight on the old one (if any)
		if currently_highlighted_pickup and is_instance_valid(currently_highlighted_pickup) and currently_highlighted_pickup.has_method("disable_highlight"):
			currently_highlighted_pickup.disable_highlight()
		
		# Enable highlight on the new one (if any)
		if closest_pickup and closest_pickup.has_method("enable_highlight"):
			closest_pickup.enable_highlight()
		
		# Update the reference
		currently_highlighted_pickup = closest_pickup

# Helper to safely remove invalid instances from the list
func remove_invalid_pickup(pickup: PickupObject):
	if nearby_pickups.has(pickup):
		nearby_pickups.erase(pickup)

# --- End Pickup Highlighting Logic ---

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

func _handle_movement() -> void:
	# Per-player input
	var input_dir := Input.get_vector(
		"move_left_p%d" % player_index, 
		"move_right_p%d" % player_index, 
		"move_forward_p%d" % player_index, 
		"move_backward_p%d" % player_index
		)
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

func pick_up_item(item_node: PickupObject): # Changed type hint
	var parent = get_parent()
	for child in parent.get_children():
		if child != self and child is CharacterBody3D and child.has_method("clear_held_item_if_matches"):
			child.clear_held_item_if_matches(item_node)
	
	if held_item == null:
		held_item = item_node
		attach_item_to_hand(item_node)

		# Ensure the just picked up item is no longer highlighted
		if currently_highlighted_pickup == item_node:
			currently_highlighted_pickup = null # Clear reference
			# Highlight should be disabled by _update_pickup_highlight because held_item is now set

		# When picking up, remove from countertop
		var ingredient_script_node = item_node.find_child("Ingredient Script Holder", true, false)
		if ingredient_script_node and ingredient_script_node.has_method("remove_from_countertop"):
			ingredient_script_node.remove_from_countertop()
		else:
			# Fallback: Check if the script is on the root item itself
			if item_node.has_method("remove_from_countertop"):
				item_node.remove_from_countertop()

		print("player is holding: " + held_item.name)

func clear_held_item_if_matches(item_node):
	if held_item == item_node:
		held_item = null

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

		# Find the node with the ingredient script and call set_countertop
		var ingredient_script_node = item.find_child("Ingredient Script Holder", true, false) # Recursive search, ignore owner
		if ingredient_script_node and ingredient_script_node.has_method("set_countertop"):
			ingredient_script_node.set_countertop(countertop)
		else:
			# Fallback: Check if the script is on the root item itself (less likely now)
			if item.has_method("set_countertop"):
				item.set_countertop(countertop)
			else:
				printerr("Could not find ingredient script with set_countertop method on ", item.name)

	else:
		print("SnapPoint not found on countertop: ", countertop.name)

func _drop_item_in_front(item):
	item.reparent(get_parent()) # Reparent to the main scene tree
	item.global_transform.origin = global_transform.origin + facing_direction * 1.5 # Use facing direction
	if item is RigidBody3D:
		item.freeze = false
		# item.apply_impulse(Vector3.ZERO, Vector3(0, 1, -2)) # Optional impulse

	# Find the node with the ingredient script and call remove_from_countertop
	var ingredient_script_node = item.find_child("Ingredient Script Holder", true, false)
	if ingredient_script_node and ingredient_script_node.has_method("remove_from_countertop"):
		ingredient_script_node.remove_from_countertop()
	else:
		# Fallback: Check if the script is on the root item itself
		if item.has_method("remove_from_countertop"):
			item.remove_from_countertop()

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
