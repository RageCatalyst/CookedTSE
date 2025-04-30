extends Node3D
class_name PickupObject

signal item_picked_up

@export var item_name: String = ""  # Set the item type
@export var pickup_range: float = 2.0  # How clos the player must be

@onready var pickup_label: Label3D = $"Pickup Label"

@onready var timer_node: Timer = get_node("/root/Multiplayer/Level/Timer")

var timer_started = false # Ensures timer only starts the one time

var player_in_range = false
var player = null
var _is_on_countertop: bool = false # NEW: Track if the ingredient is on a countertop

func _ready():
	pickup_label.visible = false  # Hide label initially
	self.connect("item_picked_up", timer_node._on_item_picked_up)

	
func _process(_delta):
	# Allow pickup interaction regardless of countertop status
	if player_in_range and Input.is_action_just_pressed("interact"):
		_pickup()

	# move label
	# Ensure label exists before trying to access it
	if is_instance_valid(pickup_label):
		pickup_label.global_transform.origin = global_transform.origin + Vector3(0, 1.5, 0)

func _drop():
	print(player.name + " dropped " + item_name)
	player.drop_item(self)

func _pickup():
	# If it was on a countertop, tell the ingredient script to clear its countertop state
	if _is_on_countertop:
		# Find the child ingredient node and tell it to clear its countertop reference
		for child in get_children():
			if child is IngredientBase: # Check if the child has the IngredientBase script/class_name
				child.clear_countertop()
				break # Assume only one ingredient child

	emit_signal("item_picked_up") # Emit signal for timer
	print(player.name + " picked up " + item_name)
	player.pick_up_item(self)
	if is_instance_valid(pickup_label): # Check label validity
		pickup_label.visible = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player = body
		# Show pickup label if player is in range and not holding anything
		if is_instance_valid(pickup_label): # Check label validity
			if player.held_item == null:
				pickup_label.visible = true
			else:
				pickup_label.visible = false


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player = null
		if is_instance_valid(pickup_label): # Check label validity
			pickup_label.visible = false # Hide label when player leaves

# Called by the child ingredient script when it's placed on/removed from a countertop
func set_on_countertop_status(status: bool):
	print("PickupObject " + str(item_name) + " received set_on_countertop_status: " + str(status))
	_is_on_countertop = status

	# Update label visibility: Show if player is in range and not holding anything
	if is_instance_valid(pickup_label): # Check label validity
		if player_in_range and player and player.held_item == null:
			pickup_label.visible = true
		else:
			pickup_label.visible = false
