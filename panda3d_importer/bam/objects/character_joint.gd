extends PandaMovingPartMatrix
class_name PandaCharacterJoint
## A joint of a Character object (analogous to the bone of a [Skeleton3D]).
##
## This object contains character joint specific values, such as a pointer back
## to the character the joint belongs to, as well as the nodes it transforms.
## It also has the value of the inverse initial net transform.
## [br][br]
## Most of these values are Panda3D-engine specific, and what we really need is
## inherited: [member PandaMovingPartMatrix.value] and
## [member PandaMovingPartMatrix.default_value].

var character: PandaCharacter

var _net_transform_nodes: Array[WeakRef]
func get_net_transform_nodes() -> Array[PandaNode]:
	var array: Array[PandaNode]
	array.assign(get_objects_from_array(_net_transform_nodes))
	return array

var _local_transform_nodes: Array[WeakRef]
func get_local_transform_nodes() -> Array[PandaNode]:
	var array: Array[PandaNode]
	array.assign(get_objects_from_array(_local_transform_nodes))
	return array

var initial_net_transform_inverse: Projection

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 4]:
		character = datagram.decode_and_follow_pointer() as PandaCharacter
	_net_transform_nodes = datagram.next_object_ref_array(PandaNode)
	_local_transform_nodes = datagram.next_object_ref_array(PandaNode)
	initial_net_transform_inverse = datagram.decode_projection()

func get_bone_id() -> int:
	return character.bam_joint_id_to_bone_id[object_id]
