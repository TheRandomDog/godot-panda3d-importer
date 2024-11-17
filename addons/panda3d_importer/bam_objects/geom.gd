extends BamObject
class_name PandaGeom
## The base object representing geometry in Panda3D.
##
## This parent object contains all data needed to reconstruct the geometry,
## such as vertex data, primitives data, shading, etc.

enum AnimationType { NONE, PANDA, HARDWARE }
enum Contents { OTHER, POINT, CLIP_POINT, VECTOR, TEXCOORD, COLOR, INDEX,
	MORPH_DELTA, MATRIX, NORMAL }
enum NumericType { U8, U16, U32, PACKED_DCBA, PACKED_DABC, FLOAT, DOUBLE,
	STDFLOAT, S8, S16, S32, PACKED_UFLOAT }
enum PrimitiveType { NONE, POLYGONS, LINES, POINTS, PATCHES }
enum ShadeModel { UNIFORM, SMOOTH, FLAT_FIRST_VERTEX, FLAT_LAST_VERTEX }
enum UsageHint { CLIENT, STREAM, DYNAMIC, STATIC, UNSPECIFIED }

var o_data: PandaGeomVertexData
var o_primitives: Array[PandaGeomPrimitive]
var primitive_type: PrimitiveType
var shade_model: ShadeModel = ShadeModel.SMOOTH
var reserved: int = 0
var bounds_type: PandaNode.BoundsType = PandaNode.BoundsType.DEFAULT

func parse_object_data() -> void:
	o_data = bam_parser.decode_and_follow_pointer() as PandaGeomVertexData
	var primitives_count = bam_parser.decode_u16()
	for i in range(primitives_count):
		o_primitives.append(
			bam_parser.decode_and_follow_pointer() as PandaGeomPrimitive
		)
	primitive_type = bam_parser.decode_u8() as PrimitiveType
	shade_model = bam_parser.decode_u8() as ShadeModel
	reserved = bam_parser.decode_u16()
	if bam_parser.version >= [6, 19]:
		bounds_type = bam_parser.decode_u8() as PandaNode.BoundsType

## Creates an [Array] that will be used as the base to create an [ArrayMesh].
##
## This array includes vertex data, normals, tangents, colors, UV coordinates,
## bones, and bone weights.
func create_base_mesh_array() -> Array:
	var mesh_array := Array()
	mesh_array.resize(Mesh.ARRAY_MAX)

	# To find the data we need to reconstruct this geometry, we have to look
	# in o_data.o_arrays. o_data is a PandaGeomVertexData, and o_arrays is an
	# array of PandaGeomVertexArrayData.
	#
	# Put simply, various data about the geometry is stored in different array
	# BAM objects, and we're going to extract it and reorganize it.
	# Let's loop through o_arrays directly.
	#
	# TODO: There's other important things in PandaGeomVertexData, such as the
	# o_transform_table. Those need to be applied to the data we extract.
	for array_data in o_data.o_arrays:
		var cleaned_data := array_data._gather_mesh_data()
		
		if 'vertices' in cleaned_data:
			mesh_array[Mesh.ARRAY_VERTEX] = cleaned_data['vertices']
		if 'texcoords' in cleaned_data:
			mesh_array[Mesh.ARRAY_TEX_UV] = cleaned_data['texcoords']
		if 'normals' in cleaned_data:
			mesh_array[Mesh.ARRAY_NORMAL] = cleaned_data['normals']
		if 'tangents' in cleaned_data:
			mesh_array[Mesh.ARRAY_TANGENT] = cleaned_data['tangents']
		if 'colors' in cleaned_data:
			mesh_array[Mesh.ARRAY_COLOR] = cleaned_data['colors']
			
		if 'transform_blend_indexes' in cleaned_data:
			# This is bone data. We have to do a bit more work on this.
			mesh_array[Mesh.ARRAY_BONES] = PackedInt32Array()
			mesh_array[Mesh.ARRAY_WEIGHTS] = PackedFloat64Array()
			
			var blend_table := o_data.o_transform_blend_table
			# Let's assign weights to bones.
			for blend_index in cleaned_data['transform_blend_indexes']:
				# It is required to always have four entries (four weights per
				# bone). If we do not need it, we should simply set the bone
				# value to 0 and the weight to 0.
				#
				# n.b. Bone value being -1 is a sentinel value representing
				# the end of the bone list, so it should not be used.
				
				var next_bones: PackedInt32Array
				var next_weights: PackedFloat64Array
				if blend_table.use_eight_bone_weights:
					next_bones = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
					next_weights = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
				else:
					next_bones = PackedInt32Array([0, 0, 0, 0])
					next_weights = PackedFloat64Array([0, 0, 0, 0])
				
				var blend := blend_table.o_blends[blend_index]
				for entry_index in range(blend.entries.size()):
					var entry: PandaTransformBlend.TransformEntry = blend.entries[entry_index]
					bam_parser.ensure(
						entry.transform is PandaJointVertexTransform,
						('TransformBlendTable(%s).blends[%s].entries[%s].transform ' +
							'is not a PandaJointVertexTransform: %s') %
							[blend_table.object_id, blend_index, entry_index, entry.transform]
					)
					var joint: PandaCharacterJoint = entry.transform.o_joint
					next_bones[entry_index] = joint.get_bone_id()
					next_weights[entry_index] = entry.weight
					
				mesh_array[Mesh.ARRAY_BONES].append_array(next_bones)
				mesh_array[Mesh.ARRAY_WEIGHTS].append_array(next_weights)
	return mesh_array

## Returns the flags that should be passed to [method ArrayMesh.add_surface_from_arrays].
func get_mesh_array_flags() -> Mesh.ArrayFormat:
	if o_data.o_transform_blend_table and o_data.o_transform_blend_table.use_eight_bone_weights:
		return Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	return 0
