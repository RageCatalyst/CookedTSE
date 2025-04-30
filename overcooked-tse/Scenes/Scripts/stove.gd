extends Node3D
class_name Stove

# Enum for stove state
enum State { IDLE, COOKING, COOKING_COMPLETE, BURNT }

# --- Exports ---
@export var cooking_duration: float = 5.0 # Time to cook a valid recipe
@export var burn_duration: float = 10.0 # Time after cooking completes before it burns

# --- State ---
var current_state: State = State.IDLE
var cooking_timer: float = 0.0
# Changed from Array[Node] to Dictionary storing counts
var current_ingredient_counts: Dictionary = {}
var matched_recipe_output: String = "" # Name of the meal being cooked

# --- Node References ---
# @onready var progress_bar: ProgressBar = $ProgressBar # Example: Add a ProgressBar node
# @onready var visual_indicator: Node3D = $VisualIndicator # Example: Fire/steam effect

# --- Recipes ---
# Key: Output meal name (String)
# Value: Dictionary { Ingredient Name (String): Count (int) }
const recipes = {
	"Onion Soup": { "chopped onion": 3 }
	# Add more recipes here, e.g.,
	# "Mushroom Soup": { "Chopped Mushroom": 2, "Chopped Onion": 1 },
	# "Tomato Soup": { "Chopped Tomato": 3 }
}

func _ready():
	# Add this node to the "stoves" group so the countertop can find it
	add_to_group("stoves")
	# Initialize visuals/progress bar if used
	# if progress_bar: progress_bar.visible = false
	# if visual_indicator: visual_indicator.visible = false
	pass

func _process(delta: float):
	match current_state:
		State.COOKING:
			cooking_timer += delta
			# Update progress bar if used
			# if progress_bar: progress_bar.value = (cooking_timer / cooking_duration) * 100

			if cooking_timer >= cooking_duration:
				_finish_cooking()

		State.COOKING_COMPLETE:
			cooking_timer += delta
			# Optional: Visual indication that it's ready (e.g., flashing)
			if cooking_timer >= burn_duration:
				_burn_food()

		State.IDLE:
			# Can potentially check if ingredients match a recipe automatically
			pass
		State.BURNT:
			# Food is burnt, maybe show smoke
			pass


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
				# Optional: Show visual indicator that recipe is ready to cook
				return true
	# No recipe matched or validation failed
	return false


func _start_cooking():
	print("Stove: Starting to cook ", matched_recipe_output)
	current_state = State.COOKING
	cooking_timer = 0.0
	# Ingredients are already consumed/deleted, no need to clear nodes here.
	# Show progress bar/cooking visuals
	# if progress_bar: progress_bar.visible = true
	# if visual_indicator: visual_indicator.visible = true # e.g., turn on fire


func _finish_cooking():
	print("Stove: Finished cooking ", matched_recipe_output)
	current_state = State.COOKING_COMPLETE
	cooking_timer = 0.0 # Reset timer for burn duration
	# Update visuals (e.g., hide progress, show "ready" indicator)
	# if progress_bar: progress_bar.visible = false


func _burn_food():
	print("Stove: ", matched_recipe_output, " has burnt!")
	current_state = State.BURNT
	# Update visuals (e.g., show smoke, burnt food model)
	# if visual_indicator: visual_indicator.visible = false # Hide fire
	# Need a burnt food visual/representation


func _deliver_meal():
	print("Stove: Delivering ", matched_recipe_output)
	# TODO: Implement meal spawning/delivery
	# 1. Find the PackedScene for the meal (e.g., load("res://Scenes/Meals/onion_soup.tscn"))
	# 2. Instantiate the meal scene
	# 3. Place the meal (e.g., on the stove, or give to player?)
	# For now, just clear ingredient counts

	_clear_ingredients() # Clears counts
	current_state = State.IDLE
	matched_recipe_output = ""
	# Reset visuals


func _clear_burnt_food():
	print("Stove: Clearing burnt food.")
	# TODO: Implement clearing burnt food (maybe requires interaction with bin?)
	_clear_ingredients() # Clears counts
	current_state = State.IDLE
	matched_recipe_output = ""
	# Reset visuals


func _clear_ingredients():
	print("Stove: Clearing ingredient counts.")
	# No nodes to free, just clear the counts dictionary
	current_ingredient_counts.clear()
	matched_recipe_output = "" # Ensure matched recipe is cleared too


# Helper needed for add_ingredient/remove_ingredient
# Assumes the PickupObject script has this method
# REMINDER: Ensure pickup_object.gd has this method!
# func get_item_name() -> String:
#     return item_name
