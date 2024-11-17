extends EggEntry
class_name EggPointLight

var vertex_ref: EggVertexRef

func read_child(child: Dictionary):
	if child['type'] != 'VertexRef':
		return
	vertex_ref = EggVertexRef.new(egg_parser, child)

func make_light(egg_parser: EggParser) -> OmniLight3D:
	var light := OmniLight3D.new()
	#light.position = vertex_ref.resolve_verticies(egg_parser)[0].position
	light.position = vertex_ref.verticies[0].position
	return light
