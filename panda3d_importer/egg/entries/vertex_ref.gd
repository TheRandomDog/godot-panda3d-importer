extends EggEntry
class_name EggVertexRef

#var indicies: PackedInt32Array
#var pool_name: String
var verticies: Array[EggVertex]
var weight := 1.0

func is_point() -> bool:
	return verticies.size() == 1

func is_triangle() -> bool:
	return verticies.size() == 3

func is_quad() -> bool:
	return verticies.size() == 4
	
func resolve_verticies(pool_name: String) -> void:
	var split_contents: PackedStringArray = contents().split(' ', false)
	# Panda3D uses CCW winding order by default, while Godot uses CW.
	# We'll reverse the indicies to reverse the faces.
	split_contents.reverse()
	for index in split_contents:
		verticies.append(egg_parser.vertex_pools[pool_name].verticies[index.to_int()])

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Ref':
			#pool_name = child['contents']
			resolve_verticies(child['contents'])

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		'membership':
			weight = data.to_float()
