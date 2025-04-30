# ingredient.gd - Base script for all ingredients
extends Node3D
class_name IngredientBase

# --- Enums ---
enum State { WHOLE, PROCESSED }

# --- Exports (Configure per ingredient in Inspector) ---
@export var initial_state: State = State.WHOLE
@export var whole_mesh: Mesh = null
@export var processed_mesh: Mesh = null
@export var processed_scene: PackedScene = null # Scene to spawn when processed (e.g., ChoppedOnion.tscn)
@export var processing_time: float = 2.0 # Time needed to process (e.g., chop)
@export var can_be_processed: bool = true # Can this ingredient be processed (chopped, cooked, etc.)?
@export var mesh_node_path: NodePath = ^"MeshInstance3D" # Export the path, default to "MeshInstance3D"

# --- State ---
var current_state: State = State.WHOLE
var _is_processing_internal: bool = false
var processing_timer: float = 0.0
var _player_can_interact: bool = false # NEW: Flag set by Player script

# --- Node References ---
# Assume this script is attached to a Node3D within the ingredient's main scene (e.g., RigidBody3D)
# The MeshInstance should be a sibling or child relative to where this script is attached.
# Adjust the path "../MeshInstanceName" as needed for your scene structure.
@onready var mesh_instance: MeshInstance3D = get_node_or_null(mesh_node_path) # NEW WAY: Use exported path
@onready var interact_label: Label3D = Label3D.new()
@onready var progress_label: Label3D = Label3D.new()

# --- Countertop Interaction ---
var current_countertop: Node = null
var on_chopping_board: bool = false # Renamed from on_required_tool


func _ready():
	current_state = initial_state
	_setup_labels()
	update_visuals()
	if not mesh_instance:
		printerr("IngredientBase: MeshInstance node not found or path is incorrect!")
	# Defer the initial visibility check to ensure labels are ready
	call_deferred("_update_interact_label_visibility")


func _setup_labels():
	# Setup Interact Label (Initially hidden)
	print("Creating interact_label...")
	interact_label = Label3D.new()
	print("interact_label instance: ", interact_label) # Check if it's null
	if not is_instance_valid(interact_label):
		printerr("Failed to create interact_label instance!")
		return # Stop if creation failed

	interact_label.text = "Hold 'F' to Process" # Generic text, can be overridden
	interact_label.visible = false
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Position slightly above the ingredient - will be set in _process
	print("Adding interact_label as child...")
	add_child(interact_label)
	print("interact_label added. Parent: ", interact_label.get_parent())

	# Setup Progress Label (Initially hidden)
	print("Creating progress_label...")
	progress_label = Label3D.new()
	#print("progress_label instance: ", progress_label)
	if not is_instance_valid(progress_label):
		printerr("Failed to create progress_label instance!")
		return

	progress_label.text = ""
	progress_label.visible = false
	progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Position higher than interact label - will be set in _process
	#print("Adding progress_label as child...")
	add_child(progress_label)
	#print("progress_label added. Parent: ", progress_label.get_parent())


func _input(event):
	# Start/Stop Processing
	# Only allow processing if:
	# - Player can interact (is close/highlighting)
	# - Ingredient can be processed
	# - Ingredient is whole
	# - Ingredient is on a chopping board
	if _player_can_interact and can_be_processed and current_state == State.WHOLE and on_chopping_board:
		if event.is_action_pressed("chop") and not _is_processing_internal: # Using "chop" action for now
			start_processing()
		elif event.is_action_released("chop") and _is_processing_internal:
			stop_processing()


func _process(delta):
	# Ensure node is in the tree before accessing global_transform or updating labels
	if not is_inside_tree():
		return

	# Update label positions to follow the ingredient
	if is_instance_valid(interact_label): # Check still needed for positioning
		interact_label.global_transform.origin = global_transform.origin + Vector3(0, 1.5, 0)
	if is_instance_valid(progress_label): # Check still needed for positioning
		progress_label.global_transform.origin = global_transform.origin + Vector3(0, 1.8, 0)

	# Update processing state
	if _is_processing_internal and current_state == State.WHOLE:
		processing_timer += delta
		var percent := int(clamp((processing_timer / processing_time) * 100, 0, 100))

		if is_instance_valid(progress_label): # Check still needed here
			progress_label.text = str(percent) + "%"
			progress_label.visible = true

		if processing_timer >= processing_time:
			finish_processing()


func start_processing():
	_is_processing_internal = true
	processing_timer = 0.0
	if is_instance_valid(progress_label):
		progress_label.visible = true
	if is_instance_valid(interact_label):
		interact_label.visible = false


func stop_processing():
	_is_processing_internal = false
	if is_instance_valid(progress_label):
		progress_label.visible = false
		progress_label.text = ""
	# Re-evaluate interact label visibility
	_update_interact_label_visibility()


func finish_processing():
	_is_processing_internal = false
	if is_instance_valid(progress_label):
		progress_label.visible = false
		progress_label.text = ""

	if current_state == State.WHOLE:
		current_state = State.PROCESSED
		update_visuals()
		spawn_processed_item() # Handle scene spawning/replacement


func spawn_processed_item():
	# Spawns the 'processed_scene' and removes this one.
	if processed_scene:
		var processed_instance = processed_scene.instantiate()
		var original_parent = get_parent() # Get the RigidBody or main node

		# Place the new item at the same location
		processed_instance.global_transform = original_parent.global_transform

		# Add to the scene tree BEFORE trying to reparent or set countertop
		get_tree().current_scene.add_child(processed_instance)

		# If the original was on a countertop, try to place the new one there
		if current_countertop and processed_instance.has_method("set_countertop"):
			# We need the script instance on the new node to call set_countertop
			# Assuming the script is attached similarly (e.g., on a child node)
			var script_holder = processed_instance.get_node_or_null("Ingredient Script Holder") # Adjust if structure differs
			if script_holder and script_holder.has_method("set_countertop"):
				script_holder.set_countertop(current_countertop)
			elif processed_instance.has_method("set_countertop"): # Fallback if script is on root
				processed_instance.set_countertop(current_countertop)

		# If set_countertop didn't handle reparenting, and it should be on the countertop, reparent manually
		# Note: This logic might need adjustment based on how set_countertop works
		if current_countertop and processed_instance.get_parent() != current_countertop:
			if current_countertop.has_method("place_item"): # Prefer countertop's method
				# Need to ensure we pass the correct node (e.g., the RigidBody)
				current_countertop.place_item(processed_instance)
			else: # Simple reparent fallback
				processed_instance.reparent(current_countertop)


		original_parent.queue_free() # Remove the original ingredient (RigidBody and its children)
	else:
		# If no processed scene, just update mesh (already done in finish_processing -> update_visuals)
		print("Ingredient processed, mesh updated.")


func update_visuals():
	# Updates the mesh based on the current state
	if not is_instance_valid(mesh_instance):
		#printerr("Cannot update visuals: MeshInstance is not valid.")
		return

	match current_state:
		State.WHOLE:
			if whole_mesh:
				mesh_instance.mesh = whole_mesh
			else:
				mesh_instance.visible = false # Hide if no mesh defined
		State.PROCESSED:
			if processed_mesh:
				mesh_instance.mesh = processed_mesh
			elif not processed_scene: # If no processed scene, hide mesh if no processed mesh either
				mesh_instance.visible = false
			# If there IS a processed_scene, this node will be queue_freed soon, so mesh doesn't matter


func set_countertop(countertop_node):
	print("Setting countertop: ", countertop_node.name)
	current_countertop = countertop_node
	on_chopping_board = false # Reset first

	if can_be_processed and is_instance_valid(current_countertop):
		# Check if the countertop has a chopping board
		if current_countertop.has_method("has_chopping_board") and current_countertop.has_chopping_board():
			on_chopping_board = true

	# Notify the parent pickup script
	var parent_pickup = get_parent()
	# --- DEBUG PRINT --- 
	## print("[Ingredient] Attempting set_on_countertop_status(true) on parent: ", parent_pickup.name if parent_pickup else "null", " Script: ", parent_pickup.get_script() if parent_pickup else "none")
	# --- END DEBUG --- 
	if parent_pickup and parent_pickup.has_method("set_on_countertop_status"):
		parent_pickup.set_on_countertop_status(true)
	else:
		printerr("Ingredient parent does not have set_on_countertop_status method!")

	_update_interact_label_visibility() # Update interact label visibility


func remove_from_countertop():
	# Notify the parent pickup script first
	var parent_pickup = get_parent()
	# --- DEBUG PRINT --- 
	## print("[Ingredient] Attempting set_on_countertop_status(false) on parent: ", parent_pickup.name if parent_pickup else "null", " Script: ", parent_pickup.get_script() if parent_pickup else "none")
	# --- END DEBUG --- 
	if parent_pickup and parent_pickup.has_method("set_on_countertop_status"):
		parent_pickup.set_on_countertop_status(false)
	# else: # Don't necessarily print error on removal, might be picked up
	# 	printerr("Ingredient parent does not have set_on_countertop_status method!")

	current_countertop = null
	on_chopping_board = false
	_update_interact_label_visibility()


func clear_countertop():
	# Called when the item is picked up
	if current_countertop and current_countertop.has_method("remove_item"):
		current_countertop.remove_item() # Let countertop know item is gone

	# Also notify pickup script that it's no longer on a countertop
	var parent_pickup = get_parent()
	# --- DEBUG PRINT --- 
	## //print("[Ingredient] Attempting set_on_countertop_status(false) on parent (clear_countertop): ", parent_pickup.name if parent_pickup else "null", " Script: ", parent_pickup.get_script() if parent_pickup else "none")
	# --- END DEBUG --- 
	if parent_pickup and parent_pickup.has_method("set_on_countertop_status"):
		parent_pickup.set_on_countertop_status(false)

	current_countertop = null
	on_chopping_board = false
	stop_processing() # Stop processing if picked up
	_player_can_interact = false # Ensure player cannot interact if picked up
	_update_interact_label_visibility()
	if is_instance_valid(interact_label):
		interact_label.visible = false


func _update_interact_label_visibility():
	# Keep the check here just in case, although deferring should prevent early calls
	if not is_instance_valid(interact_label):
		print("Attempted to update visibility, but interact_label is not valid.")
		return 

	# Show interact label only if:
	# - Player is close enough to interact <--- NEW CHECK
	# - It can be processed
	# - It's in the whole state
	# - It's on a chopping board
	# - It's NOT currently being processed
	var should_show = _player_can_interact and \
					  can_be_processed and \
					  current_state == State.WHOLE and \
					  on_chopping_board and \
					  not _is_processing_internal

	# Corrected GDScript print format
	print("Ingredient (%s): Should show interact label: %s (PlayerCanInteract: %s, CanProcess: %s, State: %s, OnBoard: %s, Processing: %s)" % \
		[name, should_show, _player_can_interact, can_be_processed, current_state, on_chopping_board, _is_processing_internal])

	interact_label.visible = should_show

# --- NEW Functions called by Player Script ---
func player_can_interact():
	print("Ingredient (%s): Player can now interact." % name) # Corrected print
	_player_can_interact = true
	_update_interact_label_visibility() # Update label when player enters range

func player_cannot_interact():
	print("Ingredient (%s): Player can no longer interact." % name) # Corrected print
	_player_can_interact = false
	stop_processing() # Stop processing if player moves away
	_update_interact_label_visibility() # Update label when player leaves range

# --- Helper Functions ---
# Optional: Add more specific checks or virtual functions for overrides

# --- Debug ---
# func _input(event): # Keep your debug input separate if needed
# 	if event.is_action_pressed("debug_next_state"):
# 		_debug_next_state()

# func _debug_next_state():
# 	# Cycle through states for debugging
# 	print("Current state: ", current_state)
# 	current_state = State.PROCESSED if current_state == State.WHOLE else State.WHOLE
# 	update_visuals()
# 	print("New state: ", current_state)



func set_outline(enabled: bool):
	# Check if the mesh_instance node reference is valid
	if not is_instance_valid(mesh_instance):
		printerr("IngredientBase ({name}): Cannot set outline, mesh_instance is invalid or path '{mesh_node_path}' is wrong!")
		return

	# Get the material override from the mesh instance
	# We assume the outline material is placed in the 'Material Override' slot
	var mat = mesh_instance.material_override

	# Check if the material override exists and is a ShaderMaterial
	if mat is ShaderMaterial:
		# Set the 'outline_enabled' parameter in the shader
		mat.set_shader_parameter("outline_enabled", enabled)
		# print(f"IngredientBase ({name}): Outline set to {enabled}") # Optional debug print
	else:
		# Print a warning if the material isn't set up correctly
		printerr("IngredientBase ({name}): Material override on '{mesh_instance.name}' is not a ShaderMaterial or is null. Cannot set outline.")
