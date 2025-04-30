# # ingredient_tomato.gd
# extends Node3D
# Change the related onion bits to tomato

# # Enum for onion states
# enum State { WHOLE, CHOPPED }

# @export var state: State = State.WHOLE
# @export var whole_mesh: Mesh = preload("res://Meshes/onion.mesh")
# @export var chopped_mesh: Mesh = preload("res://Meshes/chopped onion.mesh")
# @export var processed_scene: PackedScene = null # Assign ChoppedOnion.tscn in the editor

# @onready var mesh_instance: MeshInstance3D = $"../OnionMesh"
# @onready var interact_label: Label3D = $"../Interact Label"
# # Add a progress label above the onion
# @onready var progress_label: Label3D = Label3D.new()

# var chopping: bool = false
# var chopping_time: float = 2.0
# var chopping_timer: float = 0.0

# var current_countertop: Node = null
# var on_chopping_board: bool = false

# func _ready():
# 	update_mesh()
# 	# Setup progress label
# 	progress_label.text = ""
# 	progress_label.visible = false
# 	progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Make label always face the camera
# 	add_child(progress_label)
# 	progress_label.global_transform.origin = global_transform.origin + Vector3(0, 1.8, 0) # Position above onion

# func process():
# 	if state == State.WHOLE:
# 		state = State.CHOPPED
# 		update_mesh()
# 		# Optionally, spawn a new scene for chopped onion
# 		if processed_scene:
# 			var processed = processed_scene.instantiate()
# 			processed.global_transform = global_transform
# 			get_parent().add_child(processed)
# 			queue_free()

# func update_mesh():
# 	if state == State.WHOLE:
# 		mesh_instance.mesh = whole_mesh
# 	elif state == State.CHOPPED:
# 		mesh_instance.mesh = chopped_mesh

# func debug_next_state():
# 	# Cycle through states for debugging
# 	print("Current state: ", state)
# 	state = State.CHOPPED if state == State.WHOLE else State.WHOLE
# 	update_mesh()

# func _input(event):
# 	if event.is_action_pressed("debug_next_state"):
# 		debug_next_state()
# 	# Chopping logic: hold F to chop
# 	if on_chopping_board and state == State.WHOLE:
# 		if event.is_action_pressed("chop") and not chopping:
# 			chopping = true
# 			chopping_timer = 0.0
# 			progress_label.visible = true
# 			interact_label.visible = false # Hide interact label while chopping
# 		elif event.is_action_released("chop") and chopping:
# 			chopping = false
# 			progress_label.visible = false
# 			progress_label.text = ""
# 			interact_label.visible = true # Show interact label again if still possible

# func set_countertop(countertop: Node):
# 	current_countertop = countertop
# 	if current_countertop:
# 		current_countertop.place_item(self)
# 		# Check if this is a chopping board
# 		on_chopping_board = current_countertop.has_chopping_board() if current_countertop.has_method("has_chopping_board") else false
# 		if on_chopping_board and state == State.WHOLE:
# 			print("giving interact label")
# 			interact_label.visible = true
# 		else:
# 			interact_label.visible = false
# 	# Ensure progress label is hidden when placed
# 	if progress_label:
# 		progress_label.visible = false

# func clear_countertop():
# 	if current_countertop:
# 		current_countertop.remove_item()
# 	current_countertop = null
# 	on_chopping_board = false
# 	interact_label.visible = false
# 	# Ensure progress label is hidden when picked up
# 	if progress_label:
# 		progress_label.visible = false
# 	chopping = false # Stop chopping if picked up

# func _process(delta):
# 	# Update on_chopping_board if countertop changes
# 	if current_countertop:
# 		on_chopping_board = current_countertop.has_chopping_board() if current_countertop.has_method("has_chopping_board") else false
# 		# Hide interact label if not on chopping board, not whole, or currently chopping
# 		if not on_chopping_board or state != State.WHOLE or chopping:
# 			interact_label.visible = false
# 		# Show interact label if possible and not chopping
# 		elif on_chopping_board and state == State.WHOLE and not chopping:
# 			interact_label.visible = true
# 	else:
# 		interact_label.visible = false

# 	# Chopping progress logic
# 	if chopping and on_chopping_board and state == State.WHOLE:
# 		chopping_timer += delta
# 		var percent := int((chopping_timer / chopping_time) * 100)
# 		percent = clamp(percent, 0, 100)
# 		progress_label.text = str(percent) + "%"
# 		progress_label.visible = true
# 		progress_label.global_transform.origin = global_transform.origin + Vector3(0, 1.8, 0) # Keep label position updated
# 		if chopping_timer >= chopping_time:
# 			chopping = false
# 			progress_label.visible = false
# 			progress_label.text = ""
# 			process() # Chop the onion
# 	# Ensure progress label is hidden if chopping stops for any reason (e.g., key release handled in _input)
# 	elif not chopping and progress_label.visible:
# 		progress_label.visible = false
# 		progress_label.text = ""

# func _exit_tree():
# 	# Always hide the interact label and progress label when the onion is removed from the scene tree (e.g., picked up)
# 	if interact_label:
# 		interact_label.visible = false
# 	if progress_label:
# 		progress_label.visible = false

# # REMINDER: Call clear_countertop() in your pickup logic to ensure the label is hidden and state is reset.

# # NOTE: You must define the "chop" action in your Input Map (project.godot) and bind it to the F key for this to work.
