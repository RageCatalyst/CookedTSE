extends Timer

var label: Label
var timer_started = false  # Ensure timer only starts once

func _ready() -> void:
	label = $"../Label"
	connect("timeout", Callable(self, "_on_timer_timeout"))

func _process(_delta: float) -> void:
	var minutes = floor(time_left / 60)
	var seconds = int(time_left) % 60

	if minutes == 0 and seconds == 0:
		label.text = "02:30"
	else:
		label.text = "%02d:%02d" % [minutes, seconds]

func _on_timer_timeout() -> void:
	print("Timer stopped")
	get_tree().quit()

func _start_timer() -> void:
	if not timer_started:
		start()  # Call Timer.start() directly
		timer_started = true
		print("Timer start")
