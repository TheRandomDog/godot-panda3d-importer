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
var transform: Transform3D

func is_2d_transform() -> bool:
	return flags & IS_2D_TRANSFORM_FLAG

func is_componentwise() -> bool:
	return flags & 0x00000008

func is_quat() -> bool:
	return flags & 0x00000100

func is_matrix() -> bool:
	return flags & 0x00000040

func parse_object_data() -> void:
	flags = datagram.decode_u32()
	if bam_parser.version >= [5, 2]:
		supports_2d_transform_flag = true
	transform = Transform3D()
	if is_componentwise():
		transform.origin = datagram.decode_position(datagram.decode_stdfloat)
		var basis: Basis
		if is_quat():
			basis = Basis(datagram.decode_quaternion())
		else:
			basis = Basis(datagram.decode_rotation())
		basis = basis.scaled(datagram.decode_vector3(datagram.decode_stdfloat))
		var shear = datagram.decode_vector3(datagram.decode_stdfloat)  # TODO
		transform.basis = basis
	elif is_matrix():
		transform = datagram.decode_transform()

## Applies the transform to a given [param node].
func apply_to_node(node: Node3D, panda_node: PandaNode) -> void:
	node.transform = transform
