extends Node3D

@export var _camera_offset : Vector3
@export var player : Node3D
@export var smooth_speed : float = 5.0
var label = Label
var timer = Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label = $"../Label"
	timer = $"../Timer"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if "%02d:%02d" % time_left() == "00:00":
		label.text = "02:30"
	else:
		label.text = "%02d:%02d" % time_left()
	if player:
		var _calculated_position := player.global_transform.origin + _camera_offset
		global_transform.origin = lerp(global_transform.origin, _calculated_position, smooth_speed * delta)

func time_left():
	var minutes = floor(timer.time_left / 60)
	var seconds = int(timer.time_left) % 60
	return [minutes, seconds]

func _on_timer_timeout() -> void:
	print("Timer stop")
	get_tree().quit()
