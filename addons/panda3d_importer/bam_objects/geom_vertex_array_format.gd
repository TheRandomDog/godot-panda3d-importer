extends BamObject
class_name PandaGeomVertexArrayFormat
## An object describing the format, and how to read, a
## [PandaGeomVertexArrayData] object.

var stride: int
var total_bytes: int
var pad_to: int
var divisor: int = 0
var o_columns: Array[Dictionary]
var column_alignment: int = 1

func parse_object_data() -> void:
	stride = bam_parser.decode_u16()
	total_bytes = bam_parser.decode_u16()
	pad_to = bam_parser.decode_u8()
	if bam_parser.version >= [6, 37]:
		divisor = bam_parser.decode_u16()
	var columns_count := bam_parser.decode_u16()
	for i in range(columns_count):
		o_columns.append({
			'name': bam_parser.decode_and_follow_pointer() as PandaInternalName,
			'num_components': bam_parser.decode_u8(),
			'numeric_type': bam_parser.decode_u8() as PandaGeom.NumericType,
			'contents': bam_parser.decode_u8() as PandaGeom.Contents,
			'start': bam_parser.decode_u16(),
		})
		if bam_parser.version >= [6, 29]:
			o_columns[-1]['alignment'] = bam_parser.decode_u8()
