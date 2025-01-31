extends Node3D

@export var item_name: String = "Health Potion"  # Set the item type
@export var pickup_range: float = 2.0  # How close the player must be

@onready var pickup_label = $Label3D  # Reference the label

var player_in_range = false
var player = null

func _ready():
	pickup_label.visible = false  # Hide label initially

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):  # Check for "E" key
		_pickup()

func _pickup():
	print(player.name + " picked up " + item_name)
	queue_free()  # Remove the item from the game


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):  # Ensure the player has a "player" group
		player_in_range = true
		player = body  # Store the player reference
		pickup_label.visible = true  # Show label when player is close


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player = null
		pickup_label.visible = false  # Hide label when player leaves
