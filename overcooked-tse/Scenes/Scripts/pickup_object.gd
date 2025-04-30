extends Node3D
class_name PickupObject

signal item_picked_up

@export var item_name: String = ""  # Set the item type
# @export var pickup_range: float = 2.0 # No longer needed here, player's area handles range

# Add reference to the mesh that will have the outline
# Adjust the path if your mesh node has a different name or location
@onready var visual_mesh: MeshInstance3D = $MeshInstance3D

# Removed export
var outline_material: ShaderMaterial # Re-added non-export variable

@onready var timer_node: Timer = get_node("/root/Multiplayer/Level/Timer")

var timer_started = false # Ensures timer only starts the one time

# Removed player tracking variables, player script handles this now
# var player_in_range = false
# var player = null
var _is_on_countertop: bool = false # Track if the ingredient is on a countertop

func _ready():
	# Automatically find the ShaderMaterial in the MeshInstance3D's Material Override
	if visual_mesh and visual_mesh.material_override is ShaderMaterial:
		outline_material = visual_mesh.material_override
		# Ensure outline is initially disabled
		outline_material.set_shader_parameter("outline_enabled", false)
	else:
		printerr("PickupObject: Could not find ShaderMaterial in material_override for: ", name)

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
