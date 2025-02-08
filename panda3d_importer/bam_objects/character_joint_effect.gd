extends PandaRenderEffect
class_name PandaCharacterJointEffect

var o_character: PandaCharacter

func parse_object_data() -> void:
	super()
	o_character = bam_parser.decode_and_follow_pointer() as PandaCharacter

func apply_to_node(node: Node3D, panda_node: PandaNode) -> void:
	if node is not BoneAttachment3D:
		bam_parser.parse_warning(
			'PandaCharacterJointEffect (%s) ' % object_id +
			'expected a BoneAttachment3D but received a %s' % node
		)
		return
	
	for joint_id in o_character.bam_joint_id_to_bone_id.keys():
		var joint: PandaCharacterJoint = bam_parser.objects[joint_id]
		if panda_node in joint.o_net_transform_nodes:
			var bone_attachment = node as BoneAttachment3D
			bone_attachment.bone_idx = joint.get_bone_id()
			return
		if panda_node in joint.o_net_transform_nodes:
			bam_parser.parse_warning(
				'Local transform node found in' +
				'PandaCharacterJointEffect (%s)' % object_id +
				', this is currently not supported.'
			)
			return
