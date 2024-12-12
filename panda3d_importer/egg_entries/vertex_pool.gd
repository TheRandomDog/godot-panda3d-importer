extends EggEntry
class_name EggVertexPool

var verticies: Dictionary[int, EggVertex]

func read_child(child: Dictionary) -> void:
	if child['type'] != 'Vertex':
		return
	
	var vertex := EggVertex.new(egg_parser, child)
	verticies[vertex.id] = vertex
