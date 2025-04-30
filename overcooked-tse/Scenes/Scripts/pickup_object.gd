extends Node3D
class_name PickupObject

signal item_picked_up

@export var item_name: String = ""  # Set the item type
# @export var pickup_range: float = 2.0 # No longer needed here, player's area handles range

# Add reference to the mesh that will have the outline
# Adjust the path if your mesh node has a different name or location
@export var visual_mesh: MeshInstance3D = null

# Removed export
var outline_material: ShaderMaterial # Re-added non-export variable

@onready var timer_node: Timer = get_node("/root/Multiplayer/Level/Timer")

var timer_started = false # Ensures timer only starts the one time

# Removed player tracking variables, player script handles this now
# var player_in_range = false
# var player = null
var _is_on_countertop: bool = false # Track if the ingredient is on a countertop

func _ready():
	if visual_mesh:
		if visual_mesh.mesh and visual_mesh.mesh.get_surface_count() > 0:
			# 1. Get the original base material (could be from mesh or an override)
			var original_base_material = visual_mesh.get_active_material(0)

			if original_base_material and original_base_material is StandardMaterial3D and original_base_material.next_pass is ShaderMaterial:
				# 2. Get the shared outline shader material
				var shared_outline_material = original_base_material.next_pass

				# 3. Duplicate the BASE material to make it unique
				var unique_base_material = original_base_material.duplicate()
				if not unique_base_material:
					printerr("PickupObject: Failed to duplicate base material for: ", name)
					return

				# 4. Duplicate the OUTLINE material to make it unique
				outline_material = shared_outline_material.duplicate()
				if not outline_material:
					printerr("PickupObject: Failed to duplicate outline material for: ", name)
					# Clean up the duplicated base material if outline fails
					# unique_base_material.free() # Cannot free resource directly
					return

				# 5. Assign the unique outline material to the unique base material's next_pass
				unique_base_material.next_pass = outline_material

				# 6. Assign the unique base material (with its unique next_pass)
				#    to the Surface Material Override slot 0 for this specific MeshInstance3D
				visual_mesh.set_surface_override_material(0, unique_base_material)

				# 7. Ensure outline is initially disabled on the unique outline material
				outline_material.set_shader_parameter("outline_enabled", false)

			else:
				printerr("PickupObject: Could not find StandardMaterial3D with a ShaderMaterial in next_pass for: ", name)
		else:
			printerr("PickupObject: Mesh resource has no surfaces for: ", name)
	else:
		printerr("PickupObject: Visual mesh not assigned for: ", name) # Changed error message slightly

	# Connect the signal
	self.connect("item_picked_up", timer_node._on_item_picked_up)

# Removed _process, player handles interaction input
# func _process(_delta):
# 	if player_in_range and Input.is_action_just_pressed("interact"):
# 		_pickup()

# This function is now called BY the player when interaction happens
func get_picked_up(player: CharacterBody3D):
	print(player.name + " is picking up " + item_name)
	# If it was on a countertop, tell the ingredient script to clear its countertop state
	if _is_on_countertop:
		# Find the child ingredient node and tell it to clear its countertop reference
		for child in get_children():
			if child.has_method("clear_countertop"): # Safer check
				child.clear_countertop()
				break # Assume only one ingredient child

	emit_signal("item_picked_up") # Emit signal for timer
	# Tell the player script to actually attach the item
	if player.has_method("pick_up_item"):
		player.pick_up_item(self)
	else:
		printerr("Player script missing pick_up_item method!")

	# Disable outline when picked up (player might also do this, but good to be sure)
	disable_highlight()

# Removed player detection signals
# func _on_area_3d_body_entered(body: Node3D) -> void:
# func _on_area_3d_body_exited(body: Node3D) -> void:

# Called by the child ingredient script when it's placed on/removed from a countertop
func set_on_countertop_status(status: bool):
	print("PickupObject " + str(item_name) + " received set_on_countertop_status: " + str(status))
	_is_on_countertop = status
	# No longer need to update outline visibility here
	# _update_outline_visibility()

# --- Highlight Control Functions (called by Player) ---

func enable_highlight():
	if outline_material:
		outline_material.set_shader_parameter("outline_enabled", true)

func disable_highlight():
	if outline_material:
		outline_material.set_shader_parameter("outline_enabled", false)

# Removed _update_outline_visibility, player handles this logic
# func _update_outline_visibility():
