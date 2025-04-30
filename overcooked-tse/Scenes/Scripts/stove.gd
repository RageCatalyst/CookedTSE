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
var current_ingredients: Array[Node] = [] # Ingredients currently on the stove
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

# Placeholder: How ingredients get added needs implementation
# This might be called by the player script when dropping an item onto the stove area
func add_ingredient(ingredient_node: Node):
    if current_state == State.IDLE:
        # TODO: Check if ingredient_node is a valid ingredient type
        # Assuming ingredient_node is the PickupObject root
        if ingredient_node.has_method("get_item_name"): # Check if it has item_name property/method
            print("Stove: Added ingredient - ", ingredient_node.get_item_name())
            current_ingredients.append(ingredient_node)
            # Optional: Check immediately if a recipe is matched
            _check_for_recipe()
        else:
            printerr("Stove: Tried to add node without item_name: ", ingredient_node.name)
    else:
        print("Stove: Cannot add ingredient while cooking or finished.")


# Placeholder: How ingredients are removed (e.g., player picks them up before cooking)
func remove_ingredient(ingredient_node: Node):
    if current_ingredients.has(ingredient_node):
        print("Stove: Removed ingredient - ", ingredient_node.get_item_name())
        current_ingredients.erase(ingredient_node)
        # If cooking was based on this, maybe stop? For now, assume cooking only starts manually.


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
    var current_counts = {}

    # Count current ingredients by name
    for item in current_ingredients:
        if item.has_method("get_item_name"):
            var item_name = item.get_item_name()
            current_counts[item_name] = current_counts.get(item_name, 0) + 1

    # Check against each recipe
    for meal_name in recipes:
        var recipe_reqs = recipes[meal_name]
        var recipe_matches = true # Renamed variable from 'match'
        # Check if counts match exactly (both ingredient types and amounts)
        if current_counts.size() != recipe_reqs.size():
            recipe_matches = false
        else:
            for req_item_name in recipe_reqs:
                if not current_counts.has(req_item_name) or current_counts[req_item_name] != recipe_reqs[req_item_name]:
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
    # For now, just clear ingredients

    _clear_ingredients()
    current_state = State.IDLE
    matched_recipe_output = ""
    # Reset visuals


func _clear_burnt_food():
    print("Stove: Clearing burnt food.")
    # TODO: Implement clearing burnt food (maybe requires interaction with bin?)
    _clear_ingredients()
    current_state = State.IDLE
    matched_recipe_output = ""
    # Reset visuals


func _clear_ingredients():
    print("Stove: Clearing ingredients.")
    for item in current_ingredients:
        if is_instance_valid(item):
            item.queue_free() # Remove ingredient nodes
    current_ingredients.clear()


# Helper needed for add_ingredient/remove_ingredient
# Assumes the PickupObject script has this method
# REMINDER: Ensure pickup_object.gd has this method!
# func get_item_name() -> String:
#     return item_name
