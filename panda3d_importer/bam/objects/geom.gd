extends BamObject
class_name PandaGeom
## The base object representing geometry in Panda3D.
##
## This parent object contains all data needed to reconstruct the geometry,
## such as vertex data, primitives data, shading, etc.

enum AnimationType {
	NONE,
	PANDA,
	HARDWARE
}

enum Contents {
	OTHER,
	POINT,
	CLIP_POINT,
	VECTOR,
	TEXCOORD,
	COLOR,
	INDEX,
	MORPH_DELTA,
	MATRIX,
	NORMAL
}

enum NumericType {
	U8,
	U16,
	U32,
	PACKED_DCBA,
	PACKED_DABC,
	FLOAT,
	DOUBLE,
	STDFLOAT,
	S8,
	S16,
	S32,
	PACKED_UFLOAT
}

enum PrimitiveType {
	NONE,
	POLYGONS,
	LINES,
	POINTS,
	PATCHES
}

enum ShadeModel {
	UNIFORM,
	SMOOTH,
	FLAT_FIRST_VERTEX,
	FLAT_LAST_VERTEX
}

enum UsageHint {
	CLIENT,
	STREAM,
	DYNAMIC,
	STATIC,
	UNSPECIFIED
}

var _data: WeakRef
var data: PandaGeomVertexData:
	get:
		return get_object(_data)

var _primitives: Array[WeakRef]
func get_primitives() -> Array[PandaGeomPrimitive]:
	var array: Array[PandaGeomPrimitive]
	array.assign(get_objects_from_array(_primitives))
	return array

var primitive_type: PrimitiveType
var shade_model: ShadeModel = ShadeModel.SMOOTH
var reserved: int = 0
var bounds_type: PandaNode.BoundsType = PandaNode.BoundsType.DEFAULT

func parse_object_data() -> void:
	_data = datagram.next_object_ref(PandaGeomVertexData)
	_primitives = datagram.next_object_ref_array(PandaGeomPrimitive)
	primitive_type = datagram.decode_u8() as PrimitiveType
	shade_model = datagram.decode_u8() as ShadeModel
	reserved = datagram.decode_u16()
	if bam_parser.version >= [6, 19]:
		bounds_type = datagram.decode_u8() as PandaNode.BoundsType

## Creates an [Array] that will be used as the base to create an [ArrayMesh].
##
## This array includes vertex data, normals, tangents, colors, UV coordinates,
## bones, and bone weights.
func create_base_mesh_array() -> Array:
	var mesh_array := Array()
	mesh_array.resize(Mesh.ARRAY_MAX)

	# To find the data we need to reconstruct this geometry, we have to look
	# in data.get_arrays(). data is a PandaGeomVertexData, and arrays is an
	# array of PandaGeomVertexArrayData.
	#
	# Put simply, various data about the geometry is stored in different array
	# BAM objects, and we're going to extract it and reorganize it.
	# Let's loop through arrays directly.
	#
	# TODO: There's other important things in PandaGeomVertexData, such as the
	# transform_table. Those need to be applied to the data we extract.
	for array_data in data.get_arrays():
		var cleaned_data := array_data._gather_mesh_data()

		if 'vertices' in cleaned_data:
			mesh_array[Mesh.ARRAY_VERTEX] = cleaned_data['vertices']
		if 'texcoords' in cleaned_data:
			var texcoord_names: Array[String]
			texcoord_names.assign(cleaned_data['texcoords'].keys())
			if 'texcoord' in texcoord_names:
				mesh_array[Mesh.ARRAY_TEX_UV] = cleaned_data['texcoords']['texcoord']
				texcoord_names.erase('texcoord')
			elif texcoord_names:
				mesh_array[Mesh.ARRAY_TEX_UV] = cleaned_data['texcoords'][texcoord_names.pop_back()]
			if texcoord_names:
				mesh_array[Mesh.ARRAY_TEX_UV2] = cleaned_data['texcoords'][texcoord_names.pop_back()]
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

			var blend_table := data.transform_blend_table
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

				var blend := blend_table.blends[blend_index]
				for entry_index in range(blend.entries.size()):
					var entry: PandaTransformBlend.TransformEntry = blend.entries[entry_index]
					if entry.transform is PandaJointVertexTransform:
						# Joint transforms get their associated bone ID from the Character object.
						var joint: PandaCharacterJoint = entry.transformjoint
						next_bones[entry_index] = joint.get_bone_id()
					else:
						# Other transforms have their associated bone ID set manually.
						next_bones[entry_index] = entry.transform.static_bone_id
					next_weights[entry_index] = entry.weight

				mesh_array[Mesh.ARRAY_BONES].append_array(next_bones)
				mesh_array[Mesh.ARRAY_WEIGHTS].append_array(next_weights)
	return mesh_array

## Returns the flags that should be passed to [method ArrayMesh.add_surface_from_arrays].
func get_mesh_array_flags() -> Mesh.ArrayFormat:
	if data.transform_blend_table and data.transform_blend_table.use_eight_bone_weights:
		return Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	return 0
