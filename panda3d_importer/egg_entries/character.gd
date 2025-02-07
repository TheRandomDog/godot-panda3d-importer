extends EggGeomGroup
class_name EggCharacterGroup
## A group entry describing a Panda3D model that can be animated.
##
## Inherting from [EggGeomGroup], this node will act as our entry point
## for re-creating a Panda3D "character" (a model + skeleton).

## Joints that are associated with this character.
var joints: Array[EggJoint]

## Converts this Character entry into a [Node3D]
## with a [Skeleton3D] child node.
func convert() -> Node3D:
	var node := Node3D.new()
	var skeleton := generate_skeleton()
	if skeleton.get_bone_count() > 0:
		node.add_child(skeleton)
		if polygons:
			skeleton.add_child(convert_model())
	else:
		# This character does not have any bones, so we won't create a skeleton
		# (if we tried to, the mesh would turn invisible.)
		if polygons:
			node.add_child(convert_model())
		
	_convert_node(node, skeleton)
	return node

func read_child(child: Dictionary):
	super(child)
	if child['type'] != 'Joint':
		return
	joints.append(EggJoint.new(egg_parser, child))

## Creates and returns a [Skeleton3D] node using this group's joint data.
func generate_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = 'Skeleton3D'
	_add_joints(skeleton, joints)
	skeleton.reset_bone_poses()
	return skeleton

## Reads each [EggJoint] recursively to get the joint/bone data.
func _add_joints(skeleton: Skeleton3D, joint_array: Array[EggJoint], parent_bone_id:=-1) -> void:
	for joint in joint_array:
		# Create a new bone for this EggJoint.
		var new_bone_id := skeleton.get_bone_count()
		joint.bone_id = new_bone_id
		skeleton.add_bone(joint.entry_name.replace(':', '_').replace('/', '_'))
		
		# Apply this bone's matrix value to a Transform3D,
		# and apply our rotation matrix to it.
		var transform := (
			(egg_parser.rotation_matrix.affine_inverse() * joint.transform) 
			* egg_parser.rotation_matrix
		)
		
		# This will be our bone's rest transform.
		# TODO: There's also a "default value" for each part, 
		#		perhaps that should be the rest transform instead?
		skeleton.set_bone_rest(new_bone_id, transform)
		
		if parent_bone_id >= -1:
			skeleton.set_bone_parent(new_bone_id, parent_bone_id)
		
		# Recursively check any children for more CharacterJoints.
		_add_joints(skeleton, joint.child_joints, new_bone_id)
