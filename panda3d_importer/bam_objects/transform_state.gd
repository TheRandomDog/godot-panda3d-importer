extends BamObject
class_name PandaTransformState
## A required child object of PandaNode that describes its transform.

enum CommonFlags {
	IDENTITY = 0x00010005,
	INVALID = 0x00000096,
	COMPONENTWISE_QUAT = 0x00000338,
	COMPONENTWISE_HPR = 0x00000c38,
	MATRIX = 0x00000040
}
const IS_2D_TRANSFORM_FLAG = 0x00010000

var supports_2d_transform_flag := false
var flags: int
var pos: Vector3
var quat: Quaternion
var hpr: Vector3
var scale: Vector3
var shear: Vector3
var matrix: Projection

func is_2d_transform() -> bool:
	return flags & IS_2D_TRANSFORM_FLAG

func is_componentwise() -> bool:
	return flags & 0x00000008
	
func is_quat() -> bool:
	return flags & 0x00000100

func is_matrix() -> bool:
	return flags & 0x00000040

func parse_object_data() -> void:
	flags = bam_parser.decode_u32()
	if bam_parser.version >= [5, 2]:
		supports_2d_transform_flag = true
	if is_componentwise():
		pos = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
		var rotation := bam_parser.decode_vector3(bam_parser.decode_stdfloat)
		if is_quat():
			quat = Quaternion(rotation.normalized(), bam_parser.decode_stdfloat())
		else:
			hpr = rotation
		scale = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
		shear = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
	elif is_matrix():
		matrix = bam_parser.decode_projection()

## Applies the transform to a given [param node].
func apply_to_node(node: Node3D, panda_node: PandaNode) -> void:
	var transform: Transform3D
	if flags == CommonFlags.IDENTITY:
		transform = Transform3D.IDENTITY
	elif is_componentwise():
		transform = Transform3D()
		transform.origin = pos
		var basis: Basis
		if is_quat():
			basis = Basis(quat)
		else:
			basis = Panda2Godot.get_basis_from_hpr(hpr)
		transform.basis = basis.scaled(scale)
		# TODO: Handle shear value
	elif is_matrix():
		# Undo the rotation we apply to all vertices, because the rotation needs
		# to happen around the origin of this transform.
		transform = Panda2Godot.rotate_transform_locally(
			bam_parser.rotation_matrix,
			Transform3D(matrix)
		)
	else:
		bam_parser.parse_warning("Unknown TransformState flags")
	node.transform = transform
