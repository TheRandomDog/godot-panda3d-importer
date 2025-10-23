extends BamObject
class_name PandaGeomVertexArrayData
## A byte array containing a subset of vertex data for a geometry mesh.

var _array_format: WeakRef
var array_format: PandaGeomVertexArrayFormat:
	get:
		return get_object(_array_format)

var usage_hint: PandaGeom.UsageHint
var array_datagram: PandaBAMDatagramReader

func parse_object_data() -> void:
	_array_format = datagram.next_object_ref(PandaGeomVertexArrayFormat)
	usage_hint = datagram.decode_u8() as PandaGeom.UsageHint
	array_datagram = datagram.decode_datagram()

## Returns a [Dictionary] containing mesh data suitable for Godot's [ArrayMesh]
## resource. The dictionary may contain any of the following entries:
##
## [codeblock]{
##    'vertices': PackedVector3Array(),
##    'indexes': [],  # An array containing numerical values
##    'texcoords': PackedVector2Array(),
##    'normals': PackedVector3Array(),
##    'tangents': PackedFloat32Array(),
##    'colors': PackedColorArray(),
##    'transform_blend_indexes': [],  # An array containing numerical values
## }[/codeblock]
##
## Since each [code]PandaGeomVertexArrayData[/code] object may only contain a
## subset of data, any empty entries in the dictionary will be removed.
func _gather_mesh_data() -> Dictionary:
	array_datagram.reset_cursor()

	# Store a list of transformed mesh data.
	var data := {
		'vertices': PackedVector3Array(),
		'indexes': [],
		'texcoords': {},
		'normals': PackedVector3Array(),
		'colors': PackedColorArray(),
		'transform_blend_indexes': [],
		# Panda3D stores tangents and binormals separately, whereas Godot
		# stores them together. Thus we'll keep track of them separately here,
		# but recalculate them at the end if we receive any values.
		'ptangents': PackedVector3Array(),
		'binormals': PackedVector3Array(),
	}

	# We will now begin to read the byte array containing our mesh data.
	#
	# The array_format (PandaGeomVertexArrayFormat) tells us how to read the
	# incoming byte array. In essence, the data contains multiple "columns" that
	# are interlaced. So, if you have three columns (A, B, C), you'd take turns
	# reading data from each of them: A -> B -> C -> A -> B -> C.
	# Each column describes at what byte it starts at and the length to expect.
	#
	# This continues until the byte array is out of data. Each loop should have
	# a set length known as a "stride", which is the number of bytes reserved
	# for that loop. The actual length of the data may be less.

	# TODO: We could likely optimize this further if we moved away from columns
	# being dictionaries and sliced out data array strides directly to read from.

	var stride_skip := array_format.stride - array_format.total_bytes

	while array_datagram.datagram_size_remaining > 0:
		bam_parser.ensure(
			array_format.stride <= array_datagram.datagram_size_remaining,
			("GeomVertexArrayFormat's (%s) stride is bigger than our " +
				"remaining datagram size (%s > %s)") %
				[
					array_format.object_id,
					array_format.stride,
					array_datagram.datagram_size_remaining
				]
		)

		# Let's start reading each column for this stride.
		for column in array_format.get_columns():
			var alignment_goal: int = array_datagram.cursor + column.size

			var column_name: String = column.name.name
			var numeric_type_decoder := Callable(
				array_datagram, column.numeric_type_decoder
			)
			match column.contents:
				PandaGeom.Contents.POINT:
					data.vertices.append(
						array_datagram.decode_vector3(numeric_type_decoder)
						* global_configuration.rotation_matrix
					)
				PandaGeom.Contents.TEXCOORD:
					# Panda3D's UV wrapping on the vertical axis starts at the top
					# and ends at the bottom, which is the opposite of Godot.
					# We'll flip the V coordinate here.
					var texcoords = array_datagram.decode_vector2(numeric_type_decoder)
					texcoords.y = 1 - texcoords.y
					if column_name not in data.texcoords:
						data.texcoords[column_name] = PackedVector2Array()
					data.texcoords[column_name].append(texcoords)
				PandaGeom.Contents.INDEX:
					var index = numeric_type_decoder.call()
					if column_name == 'transform_blend':
						data.transform_blend_indexes.append(index)
					else:
						data.indexes.append(index)
				PandaGeom.Contents.NORMAL:
					data.normals.append(
						array_datagram.decode_vector3(numeric_type_decoder)
					)
				PandaGeom.Contents.VECTOR:
					# As of Panda3D 1.10, normal mapping is done via three
					# separate vertex columns (normal, tangent, and binormal).
					#
					# We'll wait to get all this information to encode our
					# glTF 2.0 compatible normal mapping, which just requires
					# a binormal direction alongside a tangent.
					#
					# Also see: https://github.com/panda3d/panda3d/issues/546

					# We have to move the datagram cursor anyway, so just read
					# it, even if we don't do anything with it.
					var vector_data = array_datagram.decode_vector3(
						numeric_type_decoder
					)
					match column_name:
						'tangent':
							data.ptangents.append(vector_data)
						'binormal':
							data.binormals.append(vector_data)
						'normal':
							data.normals.append(vector_data)
				PandaGeom.Contents.COLOR:
					data.colors.append(numeric_type_decoder.call())
				_:
					push_warning('%s Skipping %s bytes of unknown column content...' % [self, alignment_goal])
					array_datagram.take_size(alignment_goal)

			if array_datagram.cursor < alignment_goal:
				array_datagram.take_size(alignment_goal - array_datagram.cursor)

		array_datagram.take_size(stride_skip)

	# We're doing reading the byte array! Let's finish up our data dictionary.

	# First, if we didn't get any tangent data, erase those two.
	# TODO: Since we erase everything at the bottom anyway, this is redundant.
	if not data.ptangents or not data.binormals:
		data.erase('ptangents')
		data.erase('binormals')
	else:
		# We must calculate the directional signs of the binormals.
		var tangents = PackedFloat32Array()
		bam_parser.ensure(
			data.ptangents.size() == data.binormals.size(),
			"The size of the tangents and binormal arrays do not match (%s != %s)" %
				[data.ptangents.size(), data.binormals.size()]
		)
		bam_parser.ensure(
			data.ptangents.size() == data.normals.size(),
			"The size of the tangents and normal arrays do not match (%s != %s)" %
				[data.ptangents.size(), data.normals.size()]
		)
		for i in range(data.ptangents.size()):
			var normal: Vector3 = data.normals[i]
			var tangent: Vector3 = data.ptangents[i]
			var binormal: Vector3 = data.binormals[i]
			var calc_binormal = tangent.cross(normal)
			var dot_product = calc_binormal.dot(binormal)
			tangents.append_array(PackedFloat32Array([
				tangent.x, tangent.y, tangent.z, 1.0 if dot_product > 0 else -1.0
			]))
		data.tangents = tangents

	# Erase any empty entries.
	for key in data.keys():
		if not data[key]:
			data.erase(key)

	return data
