extends EggEntry
class_name EggVertex

const NO_COLOR_HINT := Color(0, 0, 0, 0)
const COORD_SYSTEMS_THAT_FLIP_VS := [
	EggParser.CoordinateSystem.Z_UP,
	EggParser.CoordinateSystem.Z_UP_LEFT,
]

var id: int
var position: Vector3
var normal: Vector3
#var color := NO_COLOR_HINT
var color: Color
var _orig_uv_coords: Vector2
var uv_coords: Vector2

var joint_influences: Dictionary[EggJoint, float]

func read_entry() -> void:
	id = entry_name.to_int()
	position = EggEntry.as_vector3(entry_dict)

#func has_color():
#	return color != NO_COLOR_HINT

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Normal':
			normal = EggEntry.as_vector3(child)
		'RGBA':
			color = EggEntry.as_color(child)
		'UV':
			_orig_uv_coords = EggEntry.as_vector2(child)
			uv_coords = _orig_uv_coords
			# Panda3D's UV wrapping on the vertical axis starts at the top
			# and ends at the bottom, which is the opposite of Godot.
			# We'll flip the V coordinate here.
			if true:#egg_parser.coordinate_system in COORD_SYSTEMS_THAT_FLIP_VS:
				uv_coords.y = 1 - uv_coords.y
