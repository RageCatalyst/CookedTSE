extends Node3D

# Enum for countertop statuses
enum Status { EMPTY, CHOPPING_BOARD, STOVE, DELIVERY_CONVEYOR }
@export var status: Status = Status.EMPTY

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