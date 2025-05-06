extends HBoxContainer

@export var order_scene: PackedScene  
@export var orders: Array[String] 

var spawn_timer := 0.0

func _ready() -> void:
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
	
func remove_order():
	orders.remove_at(0)
