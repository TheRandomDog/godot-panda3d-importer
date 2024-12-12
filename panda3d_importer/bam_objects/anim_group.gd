extends BamObject
class_name PandaAnimGroup

var name: String
var o_root: PandaAnimBundle
var o_children: Array[PandaAnimGroup]

func parse_object_data() -> void:
	name = bam_parser.decode_string()
	o_root = bam_parser.decode_and_follow_pointer() as PandaAnimBundle
	
	var children_count := bam_parser.decode_u16()
	for i in range(children_count):
		o_children.append(
			bam_parser.decode_and_follow_pointer() as PandaAnimGroup
		)
