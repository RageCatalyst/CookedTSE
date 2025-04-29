# ingredient.gd
extends Node3D

@export var processed_scene: PackedScene = null  # Assign ChoppedOnion.tscn in the editor

func process():
    if processed_scene:
        var processed = processed_scene.instantiate()
        processed.global_transform = global_transform
        get_parent().add_child(processed)
        queue_free()
