extends PandaPartBundleNode
class_name PandaCharacter
## A Panda3D model that can be animated.
##
## Inherting from [PandaPartBundleNode], this node will act as our entry point
## for re-creating a Panda3D "character" (a model + skeleton).

## Maps the BAM Object IDs of each joint to the Bone IDs of our [Skeleton3D].
var bam_joint_id_to_bone_id: Dictionary

func parse_object_data() -> void:
	super()
	# These parts used to belong to the Character object, but now belong to the
	# PandaPartBundleNode that Character inherits from. Any values we get here
	# can safely be tossed.
	var parts_count := bam_parser.decode_u16()
	for i in range(parts_count):
		bam_parser.decode_pointer()

## Converts this Character BAM Object into a [VisualInstance3D] node with a
## [Skeleton3D] child node.
func convert() -> VisualInstance3D:
	var skeleton := generate_skeleton()
	var node := VisualInstance3D.new()
	node.add_child(skeleton)
	skeleton.owner = node
	convert_node(node, skeleton)
	return node

## Creates and returns a [Skeleton3D] node using this BAM Object's part bundle data.
func generate_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = 'Skeleton3D'
	
	for bundle in o_bundles:
		if bundle is PandaCharacterJointBundle:
			for group in bundle.o_children:
				bam_parser.ensure(
					group.name == '<skeleton>', 
					'Found a different group in CharacterJointBundle other than <skeleton>: %s' %
						group.name
				)  # TODO
				_check_group_for_joints(skeleton, group)
	
	skeleton.reset_bone_poses()
	return skeleton

## Checks each [PandaPartGroup] recursively to read the data of the 
## [PandaCharacterJoint] objects inside.
##
## PandaCharacterJoint inherits from PandaPartGroup, meaning they
## can be nested and have children, so we'll check recursively.
func _check_group_for_joints(skeleton: Skeleton3D, group: PandaPartGroup, parent_bone_id:=-1):
	for part in group.o_children:
		bam_parser.ensure(
			part is PandaCharacterJoint,
			'In a nested part child of a CharacterJointBundle, instead of ' +
				'PandaCharacterJont, part was: %s' % part
		)
		
		# Create a new bone for this CharacterJoint.
		var new_bone_id := skeleton.get_bone_count()
		bam_joint_id_to_bone_id[part.object_id] = new_bone_id
		skeleton.add_bone(part.name.replace(':', '_').replace('/', '_'))
		
		# Apply this bone's matrix value to a Transform3D,
		# and apply our rotation matrix to it.
		var transform := Transform3D(part.value)
		transform = ((bam_parser.rotation_matrix.affine_inverse() * transform) 
			* bam_parser.rotation_matrix)
		#skeleton.set_bone_meta(new_bone_id, 'joint_transform', transform)
		
		# This will be our bone's rest transform.
		# TODO: There's also a "default value" for each part, 
		#		perhaps that should be the rest transform instead?
		skeleton.set_bone_rest(new_bone_id, transform)
		
		if parent_bone_id >= -1:
			skeleton.set_bone_parent(new_bone_id, parent_bone_id)
		
		# Recursively check any children for more CharacterJoints.
		_check_group_for_joints(skeleton, part, new_bone_id)
