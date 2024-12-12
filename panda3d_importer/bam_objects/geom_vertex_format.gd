extends BamObject
class_name PandaGeomVertexFormat

var animation_type: PandaGeom.AnimationType
var num_transforms: int = 0
var indexed_transforms: bool = false
var o_arrays: Array[PandaGeomVertexArrayFormat]

func parse_object_data() -> void:
	animation_type = bam_parser.decode_u8() as PandaGeom.AnimationType
	num_transforms = bam_parser.decode_u16()
	indexed_transforms = bam_parser.decode_bool()
	var arrays_count := bam_parser.decode_u16()
	for i in range(arrays_count):
		o_arrays.append(
			bam_parser.decode_and_follow_pointer() as PandaGeomVertexArrayFormat
		)
