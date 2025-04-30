extends RigidBody3D

@export var item_name: String = "Carrot"  # Set the item type
@export var pickup_range: float = 2.0  # How close the player must be

@onready var pickup_label = $Label3D  # Reference the label

var timer_started = false # Ensures timer only starts the one time

var player_in_range = false
var player = null
var is_on_countertop: bool = false # Flag to track if on countertop

func _ready():
	pickup_label.visible = false  # Hide label initially

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):  # Check for "E" key
		# Only allow pickup if not on a countertop (or handle interaction differently)
		if not is_on_countertop:
			_pickup()

func _drop():
	print(player.name + " dropped " + item_name)
	player.drop_item(self)

func _pickup():
	if timer_started == false:
		# Assuming Timer is a sibling or child of the scene root
		var timer_node = get_tree().root.find_child("Timer", true, false) 
		if timer_node and timer_node.has_method("start"):
			timer_node.start()
			timer_started = true
			print("Timer start")
		else:
			printerr("Timer node not found or doesn't have start() method!")
	
	print(player.name + " picked up " + item_name)
	player.pick_up_item(self)
	update_pickup_label_visibility() # Update label visibility after pickup

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):  # Ensure the player has a "player" group
		player_in_range = true
		player = body  # Store the player reference
		update_pickup_label_visibility() # Update label visibility

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player = null
		update_pickup_label_visibility() # Update label visibility

# New function called by ingredient.gd
func set_on_countertop_status(status: bool):
	is_on_countertop = status
	update_pickup_label_visibility() # Update label when status changes

# New helper function to manage visibility
func update_pickup_label_visibility():
	# Debug print
	print("Updating pickup label visibility:")
	print("  player_in_range: ", player_in_range)
	print("  player: ", player)
	print("  player.held_item: ", player.held_item if player else "N/A")
	print("  is_on_countertop: ", is_on_countertop)

	var should_show = player_in_range and player != null and player.held_item == null and not is_on_countertop
	print("  Result (should_show): ", should_show)
	pickup_label.visible = should_show
