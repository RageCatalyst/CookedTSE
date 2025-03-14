extends Node3D

@export var item_name: String = "Carrot"  # Set the item type
@export var pickup_range: float = 2.0  # How close the player must be

@onready var pickup_label = $Label3D  # Reference the label

var timer_started = false # Ensures timer only starts the one time

var player_in_range = false
var player = null

func _ready():
	pickup_label.visible = false  # Hide label initially

	
func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):  # Check for "E" key
		_pickup()

func _drop():
	print(player.name + " dropped " + item_name)
	player.drop_item(self)

func _pickup():
	if timer_started == false:
		$"../Timer".start() # starts the timer when the player picks up the object for the first time (will be changed)
		timer_started = true
		print("Timer start")
	print(player.name + " picked up " + item_name)
	player.pick_up_item(self)
	pickup_label.visible = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):  # Ensure the player has a "player" group
		player_in_range = true
		player = body  # Store the player reference
		if player.held_item == null:
			pickup_label.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player = null
		pickup_label.visible = false  # Hide label when player leaves
	
