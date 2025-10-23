extends BamObject
class_name PandaGeomVertexData
## A parent object that holds the data needed to reconstruct a geometry mesh.
##
## Transform and bone transform data is held by this object. Vertex data is
## held in [member PandaGeomVertexDataarrays], an array of
## [PandaGeomVertexArrayData] objects that contain subsets of vertex data needed
## to reconstruct the geometry mesh.

var name: String
var usage_hint: PandaGeom.UsageHint

var _format: WeakRef
var format: PandaGeomVertexFormat:
	get:
		return get_object(_format)

var _arrays: Array[WeakRef]
func get_arrays() -> Array[PandaGeomVertexArrayData]:
	var array: Array[PandaGeomVertexArrayData]
	array.assign(get_objects_from_array(_arrays))
	return array

var _transform_table: WeakRef
var transform_table: PandaTransformTable:
	get:
		return get_object(_transform_table)

var _transform_blend_table: WeakRef
var transform_blend_table: PandaTransformBlendTable:
	get:
		return get_object(_transform_blend_table)

var slider_table#: SliderTable


func parse_object_data() -> void:
	name = datagram.decode_string()
	_format = datagram.next_object_ref(PandaGeomVertexFormat)
	usage_hint = datagram.decode_u8() as PandaGeom.UsageHint
	_arrays = datagram.next_object_ref_array(PandaGeomVertexArrayData)
	_transform_table = datagram.next_object_ref_or_null(PandaTransformTable)
	_transform_blend_table = datagram.next_object_ref_or_null(PandaTransformBlendTable)
	# TODO: slider_table
	slider_table = datagram.decode_pointer()#decode_and_follow_pointer(SliderTable, allow_null=true)

	# TODO: If bam_parser.version < [6, 7], we need to create a PandaSparseArray
	# for transform_blend_table and slider_table.
