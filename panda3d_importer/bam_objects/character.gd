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

## Converts this Character BAM Object into a
## [Node3D] with a [Skeleton3D] child node.
func convert() -> Node3D:
	var skeleton := generate_skeleton()
	var node := Node3D.new()
	node.add_child(skeleton)
	skeleton.owner = node
	_convert_node(node, skeleton)
	for mesh in skeleton.find_children('*', 'MeshInstance3D', true, false):
		mesh.skeleton = mesh.get_path_to(skeleton)
	return node

## Creates and returns a [Skeleton3D] node using this BAM Object's part bundle data.
func generate_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = 'Skeleton3D'
	
	# First, check our part bundles for any explicitly defined joints.
	for bundle in o_bundles:
		if bundle is PandaCharacterJointBundle:
			for group in bundle.o_children:
				bam_parser.ensure(
					group.name == '<skeleton>', 
					'Found a different group in CharacterJointBundle other than <skeleton>: %s' %
						group.name
				)  # TODO
				_check_group_for_joints(skeleton, group)
				
	# Next, we'll want to add static bones to account for any other form
	# of transform blends.
	# TODO: This would not apply to non-character models, so we either always
	# need to create a skeleton whenever a populated TransformBlendTable exists
	# (as it's the easiest in-engine way to handle weight-blended verticies),
	# or implement dynamic verticies in a different way.
	
	# We'll validate which static vertex transforms apply to this Character.
	# Most BAM files have just one character anyway, but it's good to make sure.
	var static_vertex_transforms: Array[PandaVertexTransform]
	for object in bam_parser.objects.values():
		if object is PandaVertexTransform and object is not PandaJointVertexTransform:
			static_vertex_transforms.append(object)
	for vertex_transform in static_vertex_transforms:
		# Gross
		var found := false
		for child in o_children:
			if child.node is PandaGeomNode:
				for geom_info in child.node.o_geoms:
					if geom_info.geom.o_data.o_transform_blend_table:
						for blend in geom_info.geom.o_data.o_transform_blend_table.o_blends:
							for entry in blend.entries:
								if entry.transform.object_id == vertex_transform.object_id:
									found = true
									break
							if found:
								break
					if found:
						break
			if found:
				break
		
		if found:
			var bone_id := skeleton.add_bone(
				'StaticVertexTransform%s' % vertex_transform.object_id)
			vertex_transform.static_bone_id = bone_id
			skeleton.set_bone_rest(bone_id, vertex_transform.get_static_transform())
	
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
