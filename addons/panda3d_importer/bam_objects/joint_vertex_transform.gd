extends PandaVertexTransform
class_name PandaJointVertexTransform

var o_joint: PandaCharacterJoint

func parse_object_data() -> void:
	super()
	o_joint = bam_parser.decode_and_follow_pointer() as PandaCharacterJoint
