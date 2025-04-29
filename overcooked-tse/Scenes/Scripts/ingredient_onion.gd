# ingredient_onion.gd
extends Node3D

# Enum for onion states
enum State { WHOLE, CHOPPED }

@export var state: State = State.WHOLE
@export var whole_mesh: Mesh = preload("res://Meshes/onion.mesh")
@export var chopped_mesh: Mesh = preload("res://Meshes/chopped onion.mesh")
@export var processed_scene: PackedScene = null # Assign ChoppedOnion.tscn in the editor

@onready var mesh_instance: MeshInstance3D = $"../OnionMesh"
@onready var interact_label: Label3D = $"../Interact Label"


var current_countertop: Node = null
var on_chopping_board: bool = false

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

func set_countertop(countertop: Node):
	current_countertop = countertop
	if current_countertop:
		current_countertop.place_item(self)
		# Check if this is a chopping board
		on_chopping_board = current_countertop.has_chopping_board() if current_countertop.has_method("has_chopping_board") else false
		if on_chopping_board and state == State.WHOLE:
			print("giving interact label")
			interact_label.visible = true
		else:
			interact_label.visible = false

func clear_countertop():
	if current_countertop:
		current_countertop.remove_item()
	current_countertop = null
	on_chopping_board = false
	interact_label.visible = false

func _process(_delta):
	# Update on_chopping_board if countertop changes
	if current_countertop:
		on_chopping_board = current_countertop.has_chopping_board() if current_countertop.has_method("has_chopping_board") else false
		# Hide label if not on chopping board or not whole
		if not on_chopping_board or state != State.WHOLE:
			interact_label.visible = false
	else:
		interact_label.visible = false

func _exit_tree():
	# Always hide the interact label when the onion is removed from the scene tree (e.g., picked up)
	if interact_label:
		interact_label.visible = false

# REMINDER: Call clear_countertop() in your pickup logic to ensure the label is hidden and state is reset.
