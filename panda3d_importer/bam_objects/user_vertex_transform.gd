extends PandaVertexTransform
class_name PandaUserVertexTransform

var matrix: Projection

func parse_object_data() -> void:
	super()
	matrix = bam_parser.decode_projection()

## Returns the static [Transform3D] value for this [PandaUserVertexTransform].
## This value is already pre-multiplied by the BAM Parser's rotation matrix.
func get_static_transform() -> Transform3D:
	return Transform3D(matrix) * bam_parser.rotation_matrix
