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
    "Onion Soup": { "Chopped Onion": 3 }
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
        # Optional: Consider dropping the item back if stove is busy
        # _drop_item_back(ingredient_node) # Need to implement this if desired
        return

    # Find the ingredient script node (assuming it's a child)
    var ingredient_script_node = ingredient_node.find_child("Ingredient Script Holder", true, false)

    if not ingredient_script_node or not ingredient_script_node.has_method("get_item_name") or not ingredient_script_node.has_meta("current_state"):
        printerr("Stove: Dropped item is not a valid ingredient or missing state/name info: ", ingredient_node.name)
        # Optional: Drop item back if invalid
        # _drop_item_back(ingredient_node)
        return

    # Check if the ingredient is processed
    # Accessing state directly - ensure IngredientBase.State is accessible or use integer value (1 for PROCESSED)
    # Assuming IngredientBase is globally accessible via class_name
    if ingredient_script_node.current_state != IngredientBase.State.PROCESSED:
        print("Stove: Only processed ingredients can be added. (", ingredient_node.name, " is not processed)")
        # Optional: Drop item back if not processed
        # _drop_item_back(ingredient_node)
        return

    # Ingredient is valid and processed, proceed to add
    var item_name = ingredient_script_node.get_item_name() # Get name from script node now
    print("Stove: Added processed ingredient - ", item_name)
    # Increment count in the dictionary
    current_ingredient_counts[item_name] = current_ingredient_counts.get(item_name, 0) + 1
    # --- Add this line to see the current contents ---
    print("Stove Contents: ", current_ingredient_counts)
    # --------------------------------------------------
    # Delete the dropped item node
    ingredient_node.queue_free()
    # Check if a recipe is matched now
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

func _check_for_recipe() -> bool:
    matched_recipe_output = "" # Reset

    # Check against each recipe using current_ingredient_counts directly
    for meal_name in recipes:
        var recipe_reqs = recipes[meal_name]
        var recipe_matches = true
        # Check if counts match exactly (both ingredient types and amounts)
        if current_ingredient_counts.size() != recipe_reqs.size():
            recipe_matches = false
        else:
            for req_item_name in recipe_reqs:
                if not current_ingredient_counts.has(req_item_name) or current_ingredient_counts[req_item_name] != recipe_reqs[req_item_name]:
                    recipe_matches = false
                    break # Mismatch found for this recipe

        if recipe_matches:
            print("Stove: Recipe matched - ", meal_name)
            matched_recipe_output = meal_name
            # Optional: Show visual indicator that recipe is ready to cook
            return true

    # No recipe matched
    # Optional: Clear visual indicator if shown
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


# Helper needed for add_ingredient/remove_ingredient
# Assumes the PickupObject script has this method
# REMINDER: Ensure pickup_object.gd has this method!
# func get_item_name() -> String:
#     return item_name
