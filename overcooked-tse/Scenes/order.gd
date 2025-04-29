extends Panel

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

var time_left := 20.0  # seconds for this order
var total_time := 20.0

var shake_triggered := false

@onready var tween := create_tween()

func _ready():
	scale.x = 0.0  # Start "collapsed" from the right
	tween.tween_property(self, "scale:x", 1.0, 0.4) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	

func _process(delta):
	time_left -= delta
	progress_bar.value = (time_left / total_time) * 100.0

	if time_left <= 5 and not shake_triggered:
		shake_triggered = true
		start_shake()
	
	if time_left <= 0:
		queue_free()  # remove order if time is up

func start_shake():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation_degrees", 5, 0.05)
	tween.tween_property(self, "rotation_degrees", -5, 0.1)
	tween.tween_property(self, "rotation_degrees", 0, 0.05)
