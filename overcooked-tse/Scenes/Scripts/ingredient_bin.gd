extends Node3D

# Define the enum for ingredient types
enum IngredientBinType { ONION, MUSHROOM, TOMATO }

# Export a variable to select the ingredient type in the editor
@export var bin_type: IngredientBinType = IngredientBinType.ONION

# Preload the ingredient scenes based on the enum
# Adjust these paths if your scenes are located elsewhere
const ONION_SCENE = preload("res://Scenes/Food/onion.tscn")
# Assuming mushroom and tomato scenes exist at these paths
const MUSHROOM_SCENE = null
const TOMATO_SCENE = null

# Dictionary to map enum values to scenes
var ingredient_scenes = {
	IngredientBinType.ONION: ONION_SCENE,
	IngredientBinType.MUSHROOM: MUSHROOM_SCENE,
	IngredientBinType.TOMATO: TOMATO_SCENE,
}

# This function should be called by the player when they interact
func interact(player):
	# Check if the player is already holding something
	# Assuming the player script has a way to check this, e.g., an 'held_item' variable
	if player.held_item != null:
		print("Player is already holding an item.")
		return

	# Get the correct scene based on the exported enum value
	var ingredient_scene = ingredient_scenes.get(bin_type)
	if ingredient_scene == null:
		printerr("Invalid ingredient bin type or scene not found!")
		return

	# Instantiate the ingredient
	var ingredient_instance = ingredient_scene.instantiate()

	# Add the ingredient to the scene tree FIRST
	# This makes it "live" so its transform can be manipulated
	get_tree().current_scene.add_child(ingredient_instance)

	# Tell the player to pick up the item
	# Assuming the player script has a 'pickup_item' function
	if player.has_method("pick_up_item"):
		player.pick_up_item(ingredient_instance)

		# --- Start Timer ---
		# Find the timer node (assuming it's named "Timer" in the main scene)
		# Adjust the path if necessary, e.g., get_node("/root/MainScene/Timer")
		var timer_node = get_tree().get_root().find_child("Timer", true, false) 
		if timer_node and timer_node.has_method("_start_timer"):
			timer_node._start_timer()
			print("Ingredient taken, timer started.")
		else:
			printerr("Ingredient Bin: Could not find Timer node named 'Timer' or it lacks _start_timer method.")
		# --- End Start Timer ---

	else:
		printerr("Player script does not have a 'pick_up_item' method!")
		# Clean up if pickup fails
		ingredient_instance.queue_free()

# You might need an Area3D on the ingredient bin to detect the player,
# or the player might detect the bin. This example assumes the player calls interact().
