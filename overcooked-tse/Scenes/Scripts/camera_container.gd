extends Node3D

@export var _camera_offset : Vector3
@export var player : Node3D
@export var smooth_speed : float = 5.0
var label = Label
var timer = Timer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		var _calculated_position := player.global_transform.origin + _camera_offset
		global_transform.origin = lerp(global_transform.origin, _calculated_position, smooth_speed * delta)
