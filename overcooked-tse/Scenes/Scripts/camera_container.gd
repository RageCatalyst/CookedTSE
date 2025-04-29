extends Node3D

@export var _camera_offset : Vector3
@export var player : Node3D
@export var smooth_speed : float = 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		var _calculated_position := player.global_transform.origin + _camera_offset
		global_transform.origin = lerp(global_transform.origin, _calculated_position, smooth_speed * delta)
