extends Node3D

var ingredient_type: String
var preview_material = preload("res://Materials/PreviewMaterial.tres")  # Load your existing preview material

func set_ingredient_type(type: String):
	ingredient_type = type
	update_visual()

func update_visual():
	var mesh_path = "res://meshes/" + ingredient_type + ".mesh"
	var mesh = load(mesh_path)
	
	if mesh:
		var mesh_instance = $MeshInstance
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_material(0, preview_material)  # Apply the preview material
	else:
		print("Error: Mesh not found at path: " + mesh_path)
