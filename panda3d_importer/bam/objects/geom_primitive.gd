extends BamObject
class_name PandaGeomPrimitive

var shade_model: PandaGeom.ShadeModel
var first_vertex: int
var vertices_count: int
var index_column_type: PandaGeom.NumericType
var usage_hint: PandaGeom.UsageHint
var _vertices: WeakRef
var vertices: PandaGeomVertexArrayData:
	get:
		return get_object(_vertices)

func parse_object_data() -> void:
	shade_model = datagram.decode_u8() as PandaGeom.ShadeModel

	first_vertex = datagram.decode_s32()
	vertices_count = datagram.decode_s32()
	index_column_type = datagram.decode_u8() as PandaGeom.NumericType
	usage_hint = datagram.decode_u8() as PandaGeom.UsageHint
	_vertices = datagram.next_object_ref_or_null(PandaGeomVertexArrayData)

	if bam_parser.version < [6, 6] and vertices:
		# If vertices is not null, the primitive is indexed, and vertices_count
		# should be -1. However, older BAM files might have a meaningless number
		# instead, so we'll enforce the change here.
		vertices_count = -1

func _get_primitive_type() -> Mesh.PrimitiveType:
	bam_parser.parse_error('_get_primitive_type() called on base PandaGeomPrimitive class')
	return -1

## Returns a `PackedInt32Array` containing an array of vertex indices.
func _get_vertex_indices() -> PackedInt32Array:
	if vertices:
		# Panda3D has provided us some indices already.
		return vertices._gather_mesh_data()[Mesh.ARRAY_INDEX]
	else:
		# There is no index data, so the primitive is not indexed.
		return PackedInt32Array(range(first_vertex, first_vertex + vertices_count))
