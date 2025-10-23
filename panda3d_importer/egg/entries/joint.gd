extends EggEntry
class_name EggJoint

var transform: Transform3D
var default_pose: Transform3D
var weight_refs: Array[EggVertexRef]

var child_joints: Array[EggJoint]
var bone_id: int

func read_child(child: Dictionary):
	match child['type']:
		'Transform', 'DefaultPose':
			transform = EggTransform3D.new(egg_parser, child).transform
		'Joint':
			child_joints.append(EggJoint.new(egg_parser, child))
		'VertexRef':
			var vertex_ref := EggVertexRef.new(egg_parser, child)
			for vertex in vertex_ref.verticies:
				vertex.joint_influences[self] = vertex_ref.weight
