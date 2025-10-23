extends PandaRenderEffect
class_name PandaCharacterJointEffect

var _character: WeakRef
var character: PandaCharacter:
	get:
		return get_object(_character)

func parse_object_data() -> void:
	super()
	_character = datagram.next_object_ref(PandaCharacter)

func apply_to_node(node: Node3D, panda_node: PandaNode) -> void:
	if node is not BoneAttachment3D:
		bam_parser.parse_warning(
			'PandaCharacterJointEffect (%s) ' % object_id +
			'expected a BoneAttachment3D but received a %s' % node
		)
		return

	for joint_id in character.bam_joint_id_to_bone_id.keys():
		var joint: PandaCharacterJoint = bam_parser.objects[joint_id]
		if panda_node in joint.get_net_transform_nodes():
			var bone_attachment = node as BoneAttachment3D
			bone_attachment.bone_idx = joint.get_bone_id()
			return
		if panda_node in joint.get_local_transform_nodes():
			bam_parser.parse_warning(
				'Local transform node found in' +
				'PandaCharacterJointEffect (%s)' % object_id +
				', this is currently not supported.'
			)
			return
