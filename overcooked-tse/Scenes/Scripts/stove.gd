extends Node3D
class_name Stove

# Enum for stove state
enum State { IDLE, COOKING, COOKING_COMPLETE, BURNT }

# --- Exports ---
@export var cooking_duration: float = 5.0 # Time to cook a valid recipe
@export var burn_duration: float = 10.0 # Time after cooking completes before it burns
@export var onion_soup_scene: PackedScene
@export var mushroom_soup_scene: PackedScene
@export var tomato_soup_scene: PackedScene

# --- State ---
var current_state: State = State.IDLE
var cooking_timer: float = 0.0
# Changed from Array[Node] to Dictionary storing counts
var current_ingredient_counts: Dictionary = {}
var matched_recipe_output: String = "" # Name of the meal being cooked

# --- Node References ---
# @onready var progress_bar: ProgressBar = $ProgressBar # Example: Add a ProgressBar node
# @onready var visual_indicator: Node3D = $VisualIndicator # Example: Fire/steam effect
# Add a reference to the Label3D node you will add in the scene
@onready var progress_label: Label3D = $ProgressLabel

# --- Recipes ---
# Key: Output meal name (String)
# Value: Dictionary { Ingredient Name (String): Count (int) }
const recipes = {
	"Onion Soup": { "chopped onion": 3 },
	"Mushroom Soup": { "chopped mushroom": 3 }, # Assuming 3 chopped mushrooms for now
	"Tomato Soup": { "chopped tomato": 3 } # Assuming 3 chopped tomatoes for now
	# Adjust Mushroom/Tomato recipes if needed, e.g.,
	# "Mushroom Soup": { "Chopped Mushroom": 2, "Chopped Onion": 1 },
}

func _ready():
	# Add this node to the "stoves" group so the countertop can find it
	add_to_group("stoves")
	# Initialize visuals/progress bar if used
	# if progress_bar: progress_bar.visible = false
	# if visual_indicator: visual_indicator.visible = false
	progress_label.visible = false # Start hidden

func _process(delta: float):
	match current_state:
		State.COOKING:
			cooking_timer += delta
			# Update progress label if it exists
			if progress_label:
				var percentage = clamp(int((cooking_timer / cooking_duration) * 100.0), 0, 100)
				progress_label.text = str(percentage) + "%"

			if cooking_timer >= cooking_duration:
				_finish_cooking()

		State.COOKING_COMPLETE:
			cooking_timer += delta
			# Optional: Visual indication that it's ready (e.g., flashing)
			if cooking_timer >= burn_duration:
				_burn_food()

		State.IDLE:
			 # Hide label if idle
			if progress_label and progress_label.visible:
				progress_label.visible = false
		State.BURNT:
			# Hide label if burnt
			if progress_label and progress_label.visible:
				progress_label.visible = false


# --- Public Methods (Called by Player/Countertop/Item) ---

# Called by the player script when dropping an item onto the stove area
func add_ingredient(ingredient_node: Node):
	if current_state != State.IDLE:
		print("Stove: Cannot add ingredient while cooking or finished.")
		return

	# Check 1: Does the root node (e.g., RigidBody) have the get_item_name method?
	if not ingredient_node.has_method("get_item_name"):
		printerr("Stove: Dropped item is missing get_item_name method: ", ingredient_node.name)
		return

	# Check 2: Find the ingredient script node (e.g., the Node3D child with ingredient.gd)
	var ingredient_script_node = ingredient_node.find_child("Ingredient Script Holder", true, false)
	if not ingredient_script_node:
		printerr("Stove: Dropped item is missing 'Ingredient Script Holder' child node: ", ingredient_node.name)
		return

	# Check 3: Does the ingredient script node have the current_state property?
	# (We assume it does if the node exists, but a has_property check could be added for safety)
	# if not ingredient_script_node.has_property("current_state"):
	# 	printerr("Stove: Ingredient Script Holder is missing 'current_state' property: ", ingredient_node.name)
	# 	return

	# Check 4: Is the ingredient processed?
	if ingredient_script_node.current_state != IngredientBase.State.PROCESSED:
		print("Stove: Only processed ingredients can be added. (", ingredient_node.name, " is not processed)")
		return

	# --- Ingredient is valid and processed, now check capacity and recipe validity ---
	var incoming_item_name = ingredient_node.get_item_name()

	# Calculate current total items BEFORE adding the new one
	var current_total_items = 0
	for count in current_ingredient_counts.values():
		current_total_items += count

	# Check 5: Is the stove already full (3 items)?
	if current_total_items >= 3:
		print("Stove is full! Discarding ingredient: ", incoming_item_name)
		ingredient_node.queue_free() # Discard the ingredient
		return

	# Check 6: Will this be the 3rd item? If so, check if it forms a valid recipe.
	if current_total_items == 2:
		# Create a temporary dictionary to check the potential recipe
		var potential_counts = current_ingredient_counts.duplicate() # Create a copy
		potential_counts[incoming_item_name] = potential_counts.get(incoming_item_name, 0) + 1

		if not _is_valid_recipe(potential_counts):
			print("Stove: Invalid recipe combination! Clearing stove and discarding ", incoming_item_name)
			_clear_ingredients() # Clear the existing ingredients
			ingredient_node.queue_free() # Discard the incoming ingredient
			return
		# else: It forms a valid recipe, proceed to add it normally below

	# --- Add the ingredient ---
	print("Stove: Added processed ingredient - ", incoming_item_name)
	# Increment count in the dictionary
	current_ingredient_counts[incoming_item_name] = current_ingredient_counts.get(incoming_item_name, 0) + 1
	print("Stove Contents: ", current_ingredient_counts)
	# Delete the dropped item node
	ingredient_node.queue_free()
	# Check if a recipe is matched now (this will set matched_recipe_output if count is 3 and valid)
	_check_for_recipe()

# Optional helper function if you want to drop items back
# func _drop_item_back(item_node):
# 	# This requires access to the player or a way to drop near the stove
# 	# Simplest might be just not queue_freeing it, player logic handles the rest?
# 	pass


# Called by player interaction
func interact():
	match current_state:
		State.IDLE:
			if matched_recipe_output != "":
				_start_cooking()
			else:
				print("Stove: No valid recipe matched with current ingredients.")
		State.COOKING:
			print("Stove: Already cooking.")
		State.COOKING_COMPLETE:
			_deliver_meal()
		State.BURNT:
			_clear_burnt_food()


# --- Internal Cooking Logic ---

# Helper function to check if a given dictionary of counts matches any recipe
# Does NOT modify stove state (like matched_recipe_output)
func _is_valid_recipe(counts_to_check: Dictionary) -> bool:
	# Check against each recipe
	for meal_name in recipes:
		var recipe_reqs = recipes[meal_name]
		var recipe_matches = true

		# Check if counts match exactly (both ingredient types and amounts)
		if counts_to_check.size() != recipe_reqs.size():
			recipe_matches = false
		else:
			for req_item_name in recipe_reqs:
				if not counts_to_check.has(req_item_name) or counts_to_check[req_item_name] != recipe_reqs[req_item_name]:
					recipe_matches = false
					break # Mismatch found for this recipe

		if recipe_matches:
			return true # Found a valid recipe match

	# No recipe matched
	return false


# Checks if the *current* ingredients match a recipe and sets matched_recipe_output
func _check_for_recipe() -> bool:
	matched_recipe_output = "" # Reset
	if _is_valid_recipe(current_ingredient_counts):
		# Find the matching recipe name again (could optimize this)
		for meal_name in recipes:
			var recipe_reqs = recipes[meal_name]
			var recipe_matches = true
			if current_ingredient_counts.size() != recipe_reqs.size():
				recipe_matches = false
			else:
				for req_item_name in recipe_reqs:
					if not current_ingredient_counts.has(req_item_name) or current_ingredient_counts[req_item_name] != recipe_reqs[req_item_name]:
						recipe_matches = false
						break
			if recipe_matches:
				matched_recipe_output = meal_name
				print("Stove: Recipe matched - ", meal_name)

				_start_cooking()
				# Optional: Show visual indicator that recipe is ready to cook
				return true
	# No recipe matched or validation failed
	return false


func _start_cooking():
	print("Stove: Starting to cook ", matched_recipe_output)
	current_state = State.COOKING
	cooking_timer = 0.0
	# Ingredients are already consumed/deleted, no need to clear nodes here.
	# Show progress label
	print("Stove: Cooking progress label visible")
	if progress_label:
		progress_label.text = "0%"
		progress_label.visible = true


func _finish_cooking():
	print("Stove: Finished cooking ", matched_recipe_output)
	current_state = State.COOKING_COMPLETE
	# Hide progress label
	if progress_label: progress_label.visible = false
	_deliver_meal()
	cooking_timer = 0.0 # Reset timer for burn duration


func _burn_food():
	print("Stove: ", matched_recipe_output, " has burnt!")
	current_state = State.BURNT
	# Hide progress label
	if progress_label: progress_label.visible = false
	# Update visuals (e.g., show smoke, burnt food model)


func _deliver_meal():
	print("Stove: Delivering ", matched_recipe_output)

	var countertop = get_parent() # Assuming stove is a direct child of the countertop

	# Check if the parent is a valid Countertop and has the place_item method
	if not (countertop is Countertop and countertop.has_method("place_item")):
		printerr("Stove: Parent is not a Countertop or is missing the 'place_item' method!")
		printerr("Stove: Ensure the Stove node is a direct child of a Countertop node.")
		# Clear state even if placement fails
		_clear_ingredients()
		current_state = State.IDLE
		matched_recipe_output = ""
		return

	# Check if the countertop is already occupied (place_item might also check this, but good to be safe)
	if countertop.get_item() != null:
		print("Stove: Cannot deliver meal, countertop is already occupied.")
		# Don't clear state yet, maybe player will clear the counter
		# Or, decide if the meal should be lost. For now, just stop.
		# If you want the meal lost, uncomment the lines below:
		# _clear_ingredients()
		# current_state = State.IDLE
		# matched_recipe_output = ""
		return


	var meal_scene: PackedScene = null

	# 1. Find the PackedScene for the meal
	match matched_recipe_output:
		"Onion Soup":
			if onion_soup_scene:
				meal_scene = onion_soup_scene
			else:
				printerr("Stove: Onion Soup scene not assigned in the editor!")
		"Mushroom Soup":
			if mushroom_soup_scene:
				meal_scene = mushroom_soup_scene
			else:
				printerr("Stove: Mushroom Soup scene not assigned in the editor!")
		"Tomato Soup":
			if tomato_soup_scene:
				meal_scene = tomato_soup_scene
			else:
				printerr("Stove: Tomato Soup scene not assigned in the editor!")
		_:
			printerr("Stove: Unknown matched recipe output: ", matched_recipe_output)

	if meal_scene:
		# 2. Instantiate the meal scene
		print("Stove: Spawning meal scene for ", matched_recipe_output)
		var meal_instance = meal_scene.instantiate()

		# 3. Add to scene tree BEFORE passing to place_item
		#    This ensures the node is valid when place_item tries to reparent/position it.
		get_tree().current_scene.add_child(meal_instance)

		# 4. Use the countertop's function to place the item
		countertop.place_item_from_stove(meal_instance) # place_item should handle positioning and setting current_item

		print("Stove: Spawned and placed ", matched_recipe_output, " on countertop ", countertop.name)
	else:
		print("Stove: Could not spawn meal due to missing scene assignment.")


	# Clear stove state regardless of successful spawn (as cooking is done)
	_clear_ingredients() # Clears counts
	current_state = State.IDLE
	matched_recipe_output = ""
	# Reset visuals


func _clear_burnt_food():
	print("Stove: Clearing burnt food.")
	# Hide progress label
	if progress_label: progress_label.visible = false
	# TODO: Implement clearing burnt food (maybe requires interaction with bin?)
	_clear_ingredients() # Clears counts
	current_state = State.IDLE
	matched_recipe_output = ""
	# Reset visuals


func _clear_ingredients():
	print("Stove: Clearing ingredient counts.")
	# Hide progress label if it's somehow still visible
	if progress_label: progress_label.visible = false
	# No nodes to free, just clear the counts dictionary
	current_ingredient_counts.clear()
	matched_recipe_output = "" # Ensure matched recipe is cleared too

func _unhandled_input(event: InputEvent) -> void:
	if get_parent().has_stove():
		if event.is_action_pressed("debug_start_cooking"):
			# Debug: Start cooking immediately
			matched_recipe_output = "Onion Soup" # Set a default recipe for testing
			if current_state == State.IDLE:
				_start_cooking()
			else:
				print("Stove: Cannot start cooking in current state: ", current_state)
		

# Helper needed for add_ingredient/remove_ingredient
# Assumes the PickupObject script has this method
# REMINDER: Ensure pickup_object.gd has this method!
# func get_item_name() -> String:
#     return item_name
