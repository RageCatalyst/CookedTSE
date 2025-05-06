extends Area3D

var countertop: Node3D
# Called when the node enters the scene tree for the first time.
func _ready():
	countertop = get_parent()
	add_to_group("Countertop")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Player is near countertop") # Replace with function body.
