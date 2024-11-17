extends BamObject
class_name PandaPartGroup
## The base BAM Object that defines a heirarchy of [PandaMovingPart] objects
## (typically, a skeleton).

var name: String
var o_children: Array[PandaPartGroup]

func parse_object_data() -> void:
	name = bam_parser.decode_string()
	
	if bam_parser.version == [6, 11]:
		# Old freeze-joint information that's no longer relevant
		bam_parser.decode_bool()
		bam_parser.decode_projection()
	
	var children_count = bam_parser.decode_u16()
	for i in range(children_count):
		o_children.append(
			bam_parser.decode_and_follow_pointer() as PandaPartGroup
		)
