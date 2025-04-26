# ingredient_onion.gd
extends Node3D

# Enum for onion states
enum State { WHOLE, CHOPPED }

@export var state: State = State.WHOLE
@export var whole_mesh: Mesh = preload("res://Meshes/onion.mesh")
@export var chopped_mesh: Mesh = preload("res://Meshes/chopped onion.mesh")
@export var processed_scene: PackedScene = null # Assign ChoppedOnion.tscn in the editor

@onready var mesh_instance: MeshInstance3D = get_parent().get_node("OnionMesh")

func _ready():
	update_mesh()

func process():
	if state == State.WHOLE:
		state = State.CHOPPED
		update_mesh()
		# Optionally, spawn a new scene for chopped onion
		if processed_scene:
			var processed = processed_scene.instantiate()
			processed.global_transform = global_transform
			get_parent().add_child(processed)
			queue_free()

func update_mesh():
	if state == State.WHOLE:
		mesh_instance.mesh = whole_mesh
	elif state == State.CHOPPED:
		mesh_instance.mesh = chopped_mesh

func debug_next_state():
	# Cycle through states for debugging
	print("Current state: ", state)
	state = State.CHOPPED if state == State.WHOLE else State.WHOLE
	update_mesh()

func _input(event):
	if event.is_action_pressed("debug_next_state"):
		debug_next_state()
