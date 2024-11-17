extends PandaGeomPrimitive
class_name PandaGeomTristrips
## Contains data for a triangle strips primitive.

func _get_primitive_type() -> Mesh.PrimitiveType:
	# Not PRIMITIVE_TRIANGLE_STRIP, see above
	return Mesh.PrimitiveType.PRIMITIVE_TRIANGLES

## Returns a `PackedInt32Array` containing an array of vertex indices.
## [brbr]
## [b]NOTE:[/b] The resulting array will make up actual triangles as opposed to
## triangle strips, because Panda3D uses counter-clockwise winding order (while
## Godot uses clockwise). Since we'd have to unwind it anyways to rewind it,
## it's just simpler to stick with the triangles we already got.
func _get_vertex_indices() -> PackedInt32Array:
	var strip_indices := super()
	if not strip_indices:
		return strip_indices
	
	var tri_indices := PackedInt32Array()
	var curr_indices: Array
	for i in range(strip_indices.size() - 2):
		if i % 2 == 0:  # e.g. i = 0  [0, 1, 2, 3]
			# Even-indexed tri-strip is standard winding order [0, 1, 2]
			curr_indices = strip_indices.slice(i, i + 3)
		else:  # e.g.  i = 1  [0, 1, 2, 3]
			# Odd-indexed trip-strip ping-pongs in reverse [2, 1, 3]
			curr_indices = [
				strip_indices[i + 1],
				strip_indices[i],
				strip_indices[i + 2]
			]
		# Flip it to go the opposite direction
		curr_indices.reverse()
		tri_indices.append_array(curr_indices)
		
	return tri_indices
