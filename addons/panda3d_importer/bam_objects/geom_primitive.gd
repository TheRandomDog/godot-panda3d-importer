extends BamObject
class_name PandaGeomPrimitive

var shade_model: PandaGeom.ShadeModel
var first_vertex: int
var vertices_count: int
var index_column_type: PandaGeom.NumericType
var usage_hint: PandaGeom.UsageHint
var o_vertices: PandaGeomVertexArrayData

func parse_object_data() -> void:
	shade_model = bam_parser.decode_u8() as PandaGeom.ShadeModel
	
	first_vertex = bam_parser.decode_s32()
	vertices_count = bam_parser.decode_s32()
	index_column_type = bam_parser.decode_u8() as PandaGeom.NumericType
	usage_hint = bam_parser.decode_u8() as PandaGeom.UsageHint
	o_vertices = bam_parser.decode_and_follow_pointer(true) as PandaGeomVertexArrayData

	if bam_parser.version < [6, 6] and o_vertices:
		# If vertices is not null, the primitive is indexed, and vertices_count
		# should be -1. However, older BAM files might have a meaningless number
		# instead, so we'll enforce the change here.
		vertices_count = -1

func _get_primitive_type() -> Mesh.PrimitiveType:
	bam_parser.parse_error('_get_primitive_type() called on base PandaGeomPrimitive class')
	return -1

## Returns a `PackedInt32Array` containing an array of vertex indices.
func _get_vertex_indices() -> PackedInt32Array:
	if o_vertices:
		# Panda3D has provided us some indices already.
		return o_vertices._gather_mesh_data()['indexes']
	else:
		# There is no index data, so the primitive is not indexed.
		return PackedInt32Array(range(first_vertex, first_vertex + vertices_count))
