extends Node3D

# List of currently required orders (group names)
# Example: Start with one of each soup needed

#@export var orders_manager: HBoxContainer = null # Reference to the OrdersManager node
@export var orders: Array[String]
@export var orders_manager: HBoxContainer

signal order_delivered()


func _ready():
	orders_manager = $"/root/Multiplayer/Level/CanvasLayer/UIRoot/HBoxContainer"# Adjust path as needed
	print("ordersmanager found: ", orders_manager != null)
	connect("order_delivered", Callable(orders_manager, "_on_remove_order"))
	
func _process(_delta: float) -> void:
	# Update the UI with current orders
	if orders_manager:
		orders = orders_manager.orders

# This function should be called by the player when they interact
func interact(player):
	# Check if the player is holding something
	if player.held_item == null:
		print("Player is not holding anything.")
		return

	var held_item = player.held_item
	var delivered = false

	print("current orders: ", orders)

	# Check if the held item matches any required order group
	for i in range(orders.size() - 1, -1, -1): # Iterate backwards for safe removal
		var required_group = orders[i]
		print(required_group)
		if held_item.is_in_group(required_group):
			# Order found! Remove it from the list
			orders.remove_at(i)
			print("attempting to notify ordersmanager")

 

			if orders_manager:
 

				if orders_manager.has_method("_on_order_completed"):
 

					orders_manager._on_order_completed(orders_manager.get_child(0))
 

				else:
 

					printerr("ordersmanager missing on order completed method")
 

			else:
 

				printerr("Ordersmanager reference missingd")
			print("Delivered: ", required_group)
			#orders_manager.get_child(0).queue_free()
			#order_delivered.emit("onion soup")
			orders_manager.remove_order()
			print("Remaining orders: ", orders)

			var countertop = get_parent()
			if countertop.has_method("remove_item"):
				countertop.remove_item() # Remove the item from the countertop
				held_item.queue_free() # Destroy the item
				print("Item removed from countertop and destroyed.")
			else:
				print("Warning: Countertop script missing remove_item() method. Destroying item directly.")
				held_item.queue_free()

			# Player successfully delivered, make them drop/destroy the item
			if player.has_method("drop_item"):
				# We need to ensure the item is actually destroyed *after* this interaction
				# A simple way is to have drop_item handle the queue_free()
				player.drop_item() # Pass a flag to indicate successful delivery/destruction
			else:
				print("Warning: Player script missing drop_item(bool) method. Destroying item directly.")
				held_item.queue_free()
				player.held_item = null

			delivered = true

			# Optional: Add scoring or other game logic here
			if orders.is_empty():
				print("All orders delivered!")
				# Add logic for level complete, next round, etc.
			
			break # Stop checking once an order is matched and delivered

	if not delivered:
		# This item didn't match any current orders
		print("Incorrect delivery: Item '", held_item.name, "' (Groups: ", held_item.get_groups(), ") does not match any current order.")
		# Optional: Add penalty or just ignore incorrect items

# Helper function to potentially display orders in UI later
func get_orders_as_strings() -> Array[String]:
	return orders


func _on_order_delivered() -> void:
	pass # Replace with function body.
