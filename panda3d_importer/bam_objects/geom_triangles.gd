extends PandaGeomPrimitive
class_name PandaGeomTriangles
## Contains data for a triangle primitive.

func _get_primitive_type() -> Mesh.PrimitiveType:
	return Mesh.PrimitiveType.PRIMITIVE_TRIANGLES

## Returns a `PackedInt32Array` containing an array of vertex indices.
func _get_vertex_indices() -> PackedInt32Array:
	var indices := super()
	
	# Panda3D uses counter-clockwise winding order (Godot uses clockwise),
	# so the vertex indices must be reversed.
	var fixed_indices := PackedInt32Array()
	fixed_indices.resize(indices.size())
	for i in range(0, indices.size(), 3):
		fixed_indices.append_array([
			indices[i + 2], indices[i + 1], indices[i]
		])
		
	return fixed_indices
