extends PandaGeomPrimitive
class_name PandaGeomPoints
## Contains data for a primitive made up of points.

func _get_primitive_type() -> Mesh.PrimitiveType:
	return Mesh.PrimitiveType.PRIMITIVE_POINTS

## Returns a `PackedInt32Array` containing an array of vertex indices.
func _get_vertex_indices() -> PackedInt32Array:
	var indices := super()
	# Panda3D uses counter-clockwise winding order (Godot uses clockwise),
	# so the vertex indices must be reversed.
	indices.reverse()
	return indices
