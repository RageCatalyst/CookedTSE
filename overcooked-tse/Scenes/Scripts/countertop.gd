extends Node3D
class_name Countertop

# Enum for countertop statuses
enum Status { EMPTY, CHOPPING_BOARD, STOVE, DELIVERY_CONVEYOR, INGREDIENT_BIN }
@export var status : Status

var item_on_countertop: Node = null

func _ready():
	_update_attachment_visibility()

func set_status(new_status):
	status = new_status
	_update_attachment_visibility()

func _update_attachment_visibility():
	# Deactivate all attachments first
	for child in get_children():
		if child.is_in_group("chopping_boards") or child.is_in_group("stoves") or child.is_in_group("delivery_conveyors"):
			child.visible = false
	# Activate the relevant attachment
	match status:
		Status.CHOPPING_BOARD:
			_set_attachment_visible("chopping_boards")
		Status.STOVE:
			_set_attachment_visible("stoves")
		Status.DELIVERY_CONVEYOR:
			_set_attachment_visible("delivery_conveyors")
		Status.INGREDIENT_BIN:
			_set_attachment_visible("ingredient_bins")
		_:
			pass

func _set_attachment_visible(group_name):
	for child in get_children():
		if child.is_in_group(group_name):
			child.visible = true

func has_chopping_board() -> bool:
	return status == Status.CHOPPING_BOARD

func has_stove() -> bool:
	return status == Status.STOVE

func has_delivery_conveyor() -> bool:
	return status == Status.DELIVERY_CONVEYOR

func place_item(item: Node):
	item_on_countertop = item

func remove_item():
	item_on_countertop = null

func get_item() -> Node:
	return item_on_countertop

# New helper function to get the stove node if this is a stove countertop
func get_stove_node() -> Stove:
	if status != Status.STOVE:
		return null
	for child in get_children():
		if child is Stove and child.is_in_group("stoves"):
			return child
	printerr("Countertop: Status is STOVE but no Stove child node found in 'stoves' group!")
	return null

# Called by ingredient when placed on/removed from this countertop
func set_on_countertop_status(_status: bool): # Renamed parameter to fix shadowing and unused warning
	# This function is needed to prevent errors when an ingredient calls it on its parent (this countertop).
	# You can add logic here if the countertop needs to know if an ingredient is on it.
	# For now, it just prevents the "method not found" error.
	# print("Countertop received set_on_countertop_status: ", status)
	pass
