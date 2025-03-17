@tool
extends CSGBox3D
class_name Countertop


enum PROTOCSG_COLOR {DARK, GREEN, LIGHT, ORANGE, PURPLE, RED}
const _enum_color_to_foldername := ["dark", "green", "light", "orange", "purple", "red"]

@export var block_color : PROTOCSG_COLOR = PROTOCSG_COLOR.DARK :
	set(value):
		block_color = value
		update_proto_texture()

enum PROTOCSG_STYLE {
	DEFAULT,
	CROSS,
	CONTRAST,
	DIAGONAL,
	DIAGONAL_FADED,
	GROUPED_CROSS,
	GROUPED_CHECKERS,
	CHECKERS,
	CROSS_CHECKERS,
	STAIRS,
	DOOR,
	WINDOW,
	INFO
}

@export var block_style : PROTOCSG_STYLE = PROTOCSG_STYLE.DEFAULT :
	set(value):
		block_style = value
		update_proto_texture()

var placed_object: Node3D = null 

@onready var proto_csg_component = $ProtoCSGComponent

func can_place_object() -> bool:
	var can_place = placed_object == null
	print("can_place_object is returning: ",can_place, "placed_object is null", placed_object == null,")")
	return placed_object == null

func place_object(object: Node3D):
	if can_place_object():
		placed_object = object
		object.reparent(self)
		object.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)  # Place slightly above
		object.rotation_degrees = Vector3.ZERO  # Reset rotation
		print("item placed on the countertop")
	else:
		print("cannot place item countertop is still full")
		
func remove_object() -> Node3D:
	print("REMOVING OBJECT placed object = ", placed_object)
	var obj = placed_object
	placed_object = null
	print("AFTER REMOVAL placed object = ", placed_object)
	return obj



func _ready() -> void:
	pass #if !Engine.is_editor_hint(): update_proto_texture()

func update_proto_texture() -> void:
	if proto_csg_component == null:
		return
	proto_csg_component.apply_proto_texture(
		_enum_color_to_foldername[block_color],
		block_style,
		)
