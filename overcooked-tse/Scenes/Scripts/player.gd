extends CharacterBody3D

const SPEED = 5.0
const BOOST_MULTIPLIER = 2.0 # How much faster the boost makes the player
const BOOST_DURATION = 0.2   # How long the boost lasts in seconds
const BOOST_COOLDOWN = 0.5   # How long before boost can be used again
@export var player_index: int = 0 # Assign this when instantiating the player

@export var held_item : Node3D = null
@export var held_item_ingredient_name : String

@onready var hold_position = $HoldPosition
@onready var interaction_area: Area3D = $InteractionArea # Assign in editor or ensure name matches
@onready var ray_cast: RayCast3D = $CountertopRaycast


# List to track nearby pickup objects
var nearby_pickups: Array[PickupObject] = []
# List to track nearby countertop objects
var nearby_ingredients_countertop: Array = []
# Reference to the currently highlighted object
var currently_highlighted_pickup: PickupObject = null

# Boost state variables
var is_boosting: bool = false
var boost_timer: float = 0.0
var boost_cooldown_timer: float = 0.0

func _enter_tree():
	set_multiplayer_authority(name.to_int())

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

	# --- Debug Controls ---
	# Corrected action name to "debug_process"
	if event.is_action_pressed("debug_process"): # Defined in Input Map (e.g., 'B' key)
		if held_item != null:
			# Use the existing helper to find the node with the ingredient script
			# Ensure held_item is treated as PickupObject if _get_ingredient_script expects it
			var ingredient_script_node = null
			if held_item is PickupObject:
				ingredient_script_node = _get_ingredient_script(held_item)
			else:
				# If held_item might not be a PickupObject directly, adjust finding logic
				print("DEBUG: Held item is not a PickupObject, cannot find ingredient script this way.")


			if ingredient_script_node:
				# Check if the ingredient script has the 'finish_processing' method
				if ingredient_script_node.has_method("finish_processing"):
					# Check if the ingredient has the 'current_state' property using 'in'
					if "current_state" in ingredient_script_node:
						# Check if the ingredient is in the WHOLE state
						# Access the enum via the instance: ingredient_script_node.State.WHOLE
						if ingredient_script_node.current_state == ingredient_script_node.State.WHOLE:
							print("DEBUG: Forcing processing on held item: ", held_item.name)
							ingredient_script_node.finish_processing() # Call the correct function
						else:
							print("DEBUG: Held item is not in WHOLE state (State: %s)." % ingredient_script_node.current_state)
					else:
						print("DEBUG: Ingredient script node does not have 'current_state' property.")
				else:
					print("DEBUG: Ingredient script node does not have 'finish_processing' method.")
			else:
				print("DEBUG: Could not find ingredient script node for held item.")
		else:
			print("DEBUG: Not holding any item to process.")


func _process(_delta: float) -> void:
	# DEBUG: Check held_item at the start of _process
	# print("Start _process - held_item: ", held_item)
	var interaction_handled_this_frame = false
	var currently_facing_countertop = get_facing_countertop()

	# --- Handle Interact Input --- 
	if Input.is_action_just_pressed("interact_p%d" % player_index):
		# Priority 1: Interact with countertop/bin if facing one
		if currently_facing_countertop:
			# Check if it's an ingredient bin and player is empty-handed
			if currently_facing_countertop.status == Countertop.Status.INGREDIENT_BIN and held_item == null:
				var bin_node = currently_facing_countertop.get_node_or_null("ingredient_bin")
				if bin_node and bin_node.has_method("interact"):
					print("Interact pressed, held_item is null. Interacting with bin.")
					bin_node.interact(self)
					interaction_handled_this_frame = true # Mark interaction as handled
				else:
					printerr("Countertop does not have a valid ingredient bin node with an interact method.")
			
				# Check if it's a delivery conveyor and player is holding an item
				# The conveyor's interact method will handle checking the item's group
			elif currently_facing_countertop.status == Countertop.Status.DELIVERY_CONVEYOR and held_item != null: 
				print("Interact pressed, holding item. Interacting with delivery conveyor.")
				print(currently_facing_countertop.name)
				if(currently_facing_countertop.get_node("delivery_conveyor")):
					currently_facing_countertop.get_node("delivery_conveyor").interact(self) # Call the conveyor's interact method
				else:
					printerr("PLAYERGD: Delivery conveyor node not found.")
				#currently_facing_countertop.get_node("delivery_conveyor").interact(self) # Call the conveyor's interact method
				interaction_handled_this_frame = true # Mark interaction as handled

		# Priority 2: Drop item if holding one AND interaction wasn't handled above
		if held_item and not interaction_handled_this_frame:
			drop_item()
			interaction_handled_this_frame = true # Mark interaction as handled

		# Priority 3: Pick up loose item if not holding one AND interaction wasn't handled above
		elif held_item == null and not interaction_handled_this_frame and currently_highlighted_pickup:
			if currently_highlighted_pickup.has_method("get_picked_up"):
				currently_highlighted_pickup.get_picked_up(self)
				interaction_handled_this_frame = true # Mark interaction as handled
	for ingredient in nearby_ingredients_countertop:
			
		if ingredient.can_be_processed and ingredient.current_state == IngredientBase.State.WHOLE and ingredient.on_chopping_board:
			if Input.is_action_pressed("chop_p%d" % player_index):#
				if not ingredient._is_processing_internal:
					ingredient.start_processing()
			elif Input.is_action_just_released("chop_p%d" % player_index):
				ingredient.stop_processing()
	# --- End Handle Interact Input ---


func _physics_process(delta: float) -> void:
	# --- Handle Boost Timers ---
	if boost_cooldown_timer > 0:
		boost_cooldown_timer -= delta
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false # End boost when timer runs out

	# --- Handle Boost Input ---
	# Check if boost can be activated (not already boosting, cooldown finished, moving)
	var input_dir := Input.get_vector(
		"move_left_p%d" % player_index, 
		"move_right_p%d" % player_index, 
		"move_forward_p%d" % player_index, 
		"move_backward_p%d" % player_index
		)
	if Input.is_action_just_pressed("boost_p%d" % player_index) and not is_boosting and boost_cooldown_timer <= 0 and input_dir.length_squared() > 0.1:
		is_boosting = true
		boost_timer = BOOST_DURATION
		boost_cooldown_timer = BOOST_COOLDOWN

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update pickup highlighting (still needed)
	_update_pickup_highlight()

	if held_item:
		_handle_placement_preview()
	else:
		_remove_placement_preview()

	_handle_movement()
	move_and_slide()

# --- Pickup Highlighting Logic ---

# Helper function to find the ingredient script node
func _get_ingredient_script(pickup_object: PickupObject) -> Node:
	if not is_instance_valid(pickup_object):
		return null
	# Assuming the script is on a child named "Ingredient Script Holder"
	var ingredient_node = pickup_object.find_child("Ingredient Script Holder", true, false) 
	if ingredient_node and ingredient_node.has_method("player_can_interact"): # Check for one of the methods
		return ingredient_node
	else:
		# Fallback: Check if the script might be on the pickup object root itself (less likely)
		if pickup_object.has_method("player_can_interact"):
			return pickup_object
	# printerr("Player: Could not find ingredient script node for ", pickup_object.name) # Optional: Reduce noise
	return null

func _on_interaction_area_body_entered(body: Node3D):
	# Check if the body is a PickupObject and not already in the list
	if body is PickupObject and not nearby_pickups.has(body):
		nearby_pickups.append(body)
	var ingredient_script_node = body.find_child("Ingredient Script Holder", true, false)
	if ingredient_script_node and ingredient_script_node is IngredientBase and not nearby_ingredients_countertop.has(ingredient_script_node):
		nearby_ingredients_countertop.append(ingredient_script_node)

func _on_interaction_area_body_exited(body: Node3D):
	# Remove the body if it's a PickupObject
	if body is PickupObject:
		nearby_pickups.erase(body)
		# If the exited body was the highlighted one, clear the highlight AND interaction state
		if currently_highlighted_pickup == body:
			if currently_highlighted_pickup and is_instance_valid(currently_highlighted_pickup):
				# Tell ingredient it cannot be interacted with
				var ingredient_script = _get_ingredient_script(currently_highlighted_pickup)
				if ingredient_script:
					ingredient_script.player_cannot_interact()
				
				# Disable visual highlight
				if currently_highlighted_pickup.has_method("disable_highlight"):
					currently_highlighted_pickup.disable_highlight()
					
			currently_highlighted_pickup = null
	var ingredient_script_node = body.find_child("Ingredient Script Holder", true, false)
	if ingredient_script_node and ingredient_script_node is IngredientBase:
		nearby_ingredients_countertop.erase(ingredient_script_node)
		
func _update_pickup_highlight():
	var closest_pickup: PickupObject = null
	var min_dist_sq = INF

	# If holding an item, ensure nothing is highlighted or interactable
	if held_item:
		if currently_highlighted_pickup and is_instance_valid(currently_highlighted_pickup):
			# Tell ingredient it cannot be interacted with
			var ingredient_script = _get_ingredient_script(currently_highlighted_pickup)
			if ingredient_script:
				ingredient_script.player_cannot_interact()
				
			# Disable visual highlight
			if currently_highlighted_pickup.has_method("disable_highlight"):
				currently_highlighted_pickup.disable_highlight()
				
			currently_highlighted_pickup = null
		return # Exit early if holding an item

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

	# Update highlighting and interaction state based on the closest found object
	if closest_pickup != currently_highlighted_pickup:
		# --- Handle the OLD highlighted item ---
		if currently_highlighted_pickup and is_instance_valid(currently_highlighted_pickup):
			# Tell OLD ingredient it cannot be interacted with
			var old_ingredient_script = _get_ingredient_script(currently_highlighted_pickup)
			if old_ingredient_script:
				old_ingredient_script.player_cannot_interact()
				
			# Disable OLD visual highlight
			if currently_highlighted_pickup.has_method("disable_highlight"):
				currently_highlighted_pickup.disable_highlight()

		# --- Handle the NEW highlighted item ---
		if closest_pickup and is_instance_valid(closest_pickup): # Check validity for the new one too
			# Tell NEW ingredient it can be interacted with
			var new_ingredient_script = _get_ingredient_script(closest_pickup)
			if new_ingredient_script:
				new_ingredient_script.player_can_interact()
				
			# Enable NEW visual highlight
			if closest_pickup.has_method("enable_highlight"):
				closest_pickup.enable_highlight()
		
		# Update the reference AFTER handling both old and new
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
						"onion soup":
							held_item_ingredient_name = "onion soup"
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
			return # Return if snap point found and preview handled
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

	# Determine current speed based on boost state
	var current_speed = SPEED
	if is_boosting:
		current_speed = SPEED * BOOST_MULTIPLIER

	if direction.length() > 0.1:
		facing_direction = direction
		look_at(global_transform.origin + facing_direction, Vector3.UP)

	if direction:
		velocity.x = direction.x * current_speed # Use current_speed
		velocity.z = direction.z * current_speed # Use current_speed
	else:
		# Still apply boost if moving due to inertia even if input stops
		velocity.x = move_toward(velocity.x, 0, current_speed) # Use current_speed
		velocity.z = move_toward(velocity.z, 0, current_speed) # Use current_speed

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
		# DEBUG: Check held_item immediately after assignment
		var item_name = "None"
		if held_item:
			item_name = held_item.name
		print("Inside pick_up_item - assigned held_item: ", held_item, " (Name: ", item_name, ")")

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
	# held_item = null # IMPORTANT: Don't nullify held_item here yet! The interact function might need it. Nullify AFTER successful interaction or drop.
	print("Attempting to drop/place: " + dropped_item.name)

	var countertop = get_facing_countertop()

	# Check if facing a valid countertop target
	if countertop and is_facing_target(countertop):
		# Case 1: Is it a stove countertop?
		if countertop.status == Countertop.Status.STOVE:
			var stove = countertop.get_stove_node()
			# Is the stove idle?
			if stove and stove.current_state == Stove.State.IDLE:
				print("Player adding ingredient to stove via countertop: ", dropped_item.name)
				# Stove handles deleting the node, so we can nullify player's held item
				held_item = null 
				stove.add_ingredient(dropped_item) 
				return # SUCCESS: Item added to stove
			# else: Stove is busy or invalid, fall through to drop in front

		# Case 2: Is it a non-stove, non-bin, non-conveyor countertop and empty?
		# Check it's not a conveyor by checking for the 'orders' property
		elif countertop.status != Countertop.Status.STOVE and countertop.status != Countertop.Status.INGREDIENT_BIN and not ("orders" in countertop) and countertop.get_item() == null:
			# Successfully placing item, nullify player's held item
			held_item = null 
			_snap_item_to_countertop(dropped_item, countertop)
			return # SUCCESS: Item snapped to regular countertop
		# else: Countertop is stove, bin, conveyor, or occupied, fall through to drop in front

	# Fallback: No valid countertop target, or target was occupied/busy/bin/conveyor
	# Nullify player's held item before dropping on ground
	held_item = null 
	_drop_item_in_front(dropped_item)

func _snap_item_to_countertop(item, countertop):
	# Double-check if countertop is free before proceeding (belt and braces)
	if countertop.get_item() != null:
		print("Countertop occupied, dropping in front instead.")
		_drop_item_in_front(item)
		return

	var snap_point = countertop.get_node_or_null("SnapPoint")
	if snap_point:
		# Tell the countertop it now holds this item *before* reparenting
		countertop.place_item(item)

		item.reparent(countertop)
		item.global_transform = snap_point.global_transform
		if item is RigidBody3D:
			item.freeze = true # Keep physics frozen

		# Find the node with the ingredient script and call set_countertop
		var ingredient_script_node = item.find_child("Ingredient Script Holder", true, false) # Recursive search, ignore owner
		if ingredient_script_node and ingredient_script_node.has_method("set_countertop"):
			ingredient_script_node.set_countertop(countertop)
		else:
			printerr("Player: Could not find ingredient script node or set_countertop method on dropped item:", item.name)
	else:
		printerr("Player: Countertop missing SnapPoint node:", countertop.name)
		# Fallback if snap point is missing but countertop was somehow deemed free
		_drop_item_in_front(item)

func _drop_item_in_front(item):
	item.reparent(get_parent()) # Reparent to the main scene tree
	item.global_transform.origin = global_transform.origin + facing_direction * 1.5 # Use facing direction
	if item is RigidBody3D:
		item.freeze = false # Unfreeze physics when dropped on the ground

	# Find the node with the ingredient script and call remove_from_countertop
	# This ensures its internal state knows it's not on a counter anymore
	var ingredient_script_node = item.find_child("Ingredient Script Holder", true, false)
	if ingredient_script_node and ingredient_script_node.has_method("remove_from_countertop"):
		ingredient_script_node.remove_from_countertop()
	# else: # Don't necessarily error if it wasn't on a countertop to begin with
	# 	printerr("Player: Could not find ingredient script node or remove_from_countertop method on dropped item:", item.name)

# Returns the countertop directly in front of the player using a RayCast3D node named 'CountertopRaycast'
func get_facing_countertop():
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()

		# Traverse up the tree from the collider to find the Countertop node
		var current_node = collider
		while current_node:
			if current_node is Countertop:
				return current_node
			current_node = current_node.get_parent()
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
