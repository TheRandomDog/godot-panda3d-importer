extends BamObject
class_name PandaGeomVertexData
## A parent object that holds the data needed to reconstruct a geometry mesh.
##
## Transform and bone transform data is held by this object. Vertex data is
## held in [member PandaGeomVertexData.o_arrays], an array of
## [PandaGeomVertexArrayData] objects that contain subsets of vertex data needed
## to reconstruct the geometry mesh. 

var name: String
var o_format: PandaGeomVertexFormat
var usage_hint: PandaGeom.UsageHint
var o_arrays: Array[PandaGeomVertexArrayData]
var o_transform_table: PandaTransformTable
var o_transform_blend_table: PandaTransformBlendTable
var o_slider_table#: SliderTable

func parse_object_data() -> void:
	name = bam_parser.decode_string()
	o_format = bam_parser.decode_and_follow_pointer() as PandaGeomVertexFormat
	usage_hint = bam_parser.decode_u8() as PandaGeom.UsageHint
	var arrays_count := bam_parser.decode_u16()
	for i in range(arrays_count):
		o_arrays.append(bam_parser.decode_and_follow_pointer() as PandaGeomVertexArrayData)
	o_transform_table = bam_parser.decode_and_follow_pointer(true) as PandaTransformTable
	o_transform_blend_table = bam_parser.decode_and_follow_pointer(true) as PandaTransformBlendTable
	# TODO: o_slider_table
	o_slider_table = bam_parser.decode_pointer()#decode_and_follow_pointer(SliderTable, allow_null=true)
	
	# TODO: If bam_parser.version < [6, 7], we need to create a PandaSparseArray
	# for o_transform_blend_table and o_slider_table.
