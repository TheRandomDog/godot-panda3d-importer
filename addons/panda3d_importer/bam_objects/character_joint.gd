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

var o_character: PandaCharacter
var o_net_transform_nodes: Array[PandaNode]
var o_local_transform_nodes: Array[PandaNode]
var initial_net_transform_inverse: Projection

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 4]:
		o_character = bam_parser.decode_and_follow_pointer() as PandaCharacter
		
	var net_node_count := bam_parser.decode_u16()
	for i in range(net_node_count):
		o_net_transform_nodes.append(bam_parser.decode_and_follow_pointer() as PandaNode)
		
	var local_node_count := bam_parser.decode_u16()
	for i in range(local_node_count):
		o_local_transform_nodes.append(bam_parser.decode_and_follow_pointer() as PandaNode)
		
	initial_net_transform_inverse = bam_parser.decode_projection()
		
func get_bone_id() -> int:
	return o_character.bam_joint_id_to_bone_id[object_id]
