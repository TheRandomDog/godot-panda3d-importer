extends PandaNode
class_name PandaLODNode

var center: Vector3
var switches: PackedVector2Array

func parse_object_data():
	super()
	center = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
	
	var switches_count := bam_parser.decode_u16()
	switches.resize(switches_count)
	for i in range(switches_count):
		switches[i] = bam_parser.decode_vector2(bam_parser.decode_stdfloat)
	
	if not name:
		name = 'HLOD'

## Converts this LODNode into a Godot node. [br][br] After the normal
## conversion, it will look through it's children and assign HLOD visibilities
## to any [GeometryInstance3D] nodes.
func convert() -> Node3D:
	var node := super()
	assert(node.get_child_count() == switches.size())
	for i in range(node.get_child_count()):
		var child := node.get_child(i)
		if child is GeometryInstance3D:
			child.visibility_range_begin = switches[i][1]
			child.visibility_range_begin_margin = 1.0
			child.visibility_range_end = switches[i][0]
			child.visibility_range_end_margin = 1.0
		for geometry in child.find_children('*', 'GeometryInstance3D', true, false):
			geometry.visibility_range_begin = switches[i][1]
			geometry.visibility_range_begin_margin = 1.0
			geometry.visibility_range_end = switches[i][0]
			geometry.visibility_range_end_margin = 1.0
	return node
