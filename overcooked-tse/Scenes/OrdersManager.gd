extends HBoxContainer

@export var order_scene: PackedScene  
@export var orders: Array[String] 
@export var score_tracker: NodePath

var _score_tracker: Node
var spawn_timer := 0.0

func _ready() -> void:
	_score_tracker = get_node(score_tracker)
	spawn_timer = randf_range(3, 6)  # first spawn between 3-6 seconds

func _process(delta):
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_order()
		spawn_timer = randf_range(5, 10)  # spawn next order between 5-10 seconds

func spawn_order():
	var new_order = order_scene.instantiate()
	orders.append("onion soup")
	add_child(new_order)
	print("Spawned order: ", new_order)

func _on_order_completed(order: Node):
	print("3.ordersmanager recieved order")
	print("order exists", order != null)
	print("scoretracker valid", _score_tracker != null)
	if !_score_tracker:
		printerr("4.CRITICAL: scoretracker reference broken")
		return
	print("5.calculating score")
	var score = _score_tracker.calculate_order_score(order)
	print("6.calculated score:", score)
	print("Order Delivered! Score: ", score)
	
<<<<<<< HEAD
	if has_node("/root/ScoreDisplay2"):
		get_node("/root/ScoreDisplay2").update_display(
			_score_tracker.total_score,
			_score_tracker.curent_combo,
			min(_score_tracker.current_combo, 4)
		)
=======
func remove_order():
	print("removing order")
	orders.remove_at(0)
	get_child(0).queue_free()
>>>>>>> main
