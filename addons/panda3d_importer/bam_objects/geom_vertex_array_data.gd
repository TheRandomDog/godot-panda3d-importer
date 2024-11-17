extends BamObject
class_name PandaGeomVertexArrayData
## A byte array containing a subset of vertex data for a geometry mesh.

var o_array_format: PandaGeomVertexArrayFormat
var usage_hint: PandaGeom.UsageHint
var buffer: PackedByteArray

## Decodes a DirectX style color value from a uint32 (AGBR)
func _decode_dcba() -> Color:
	# TODO: Idk, it seems like these should be flipped?
	var vector: Vector4 = bam_parser.decode_vector4(bam_parser.decode_u8)
	return Color(vector.x / 255, vector.y / 255, vector.z / 255, vector.w / 255)

## Decodes a DirectX style color value from a uint32 (ARGB)
func _decode_dabc() -> Color:
	# TODO: Idk, it seems like these should be flipped?
	var vector: Vector4 = bam_parser.decode_vector4(bam_parser.decode_u8)
	return Color(vector.z / 255, vector.y / 255, vector.x / 255, vector.w / 255)

func parse_object_data() -> void:
	o_array_format = bam_parser.decode_and_follow_pointer() as PandaGeomVertexArrayFormat
	usage_hint = bam_parser.decode_u8() as PandaGeom.UsageHint
	var buffer_size := bam_parser.decode_u32()
	buffer = bam_parser.take_size(buffer_size)

## Returns the required [Callable] from [BamParser] to decode a given
## [enum PandaGeom.NumericType].
func _get_decoder_for_numeric_type(numeric_type: PandaGeom.NumericType) -> Callable:
	match numeric_type:
		PandaGeom.NumericType.U8: return bam_parser.decode_u8
		PandaGeom.NumericType.U16: return bam_parser.decode_u16
		PandaGeom.NumericType.U32: return bam_parser.decode_u32
		PandaGeom.NumericType.S8: return bam_parser.decode_s8
		PandaGeom.NumericType.S16: return bam_parser.decode_s16
		PandaGeom.NumericType.S32: return bam_parser.decode_s32
		PandaGeom.NumericType.FLOAT: return bam_parser.decode_float
		PandaGeom.NumericType.DOUBLE: return bam_parser.decode_double
		PandaGeom.NumericType.STDFLOAT: return bam_parser.decode_stdfloat
		PandaGeom.NumericType.PACKED_DCBA: return _decode_dcba
		PandaGeom.NumericType.PACKED_DABC: return _decode_dabc
		_:
			bam_parser.parse_error('Unknown NumericType')
			return func(): pass

## Returns the number of bytes needed to read a
## given [enum PandaGeom.NumericType].
func _get_byte_offset_for_numeric_type(numeric_type: PandaGeom.NumericType) -> int:
	match numeric_type:
		PandaGeom.NumericType.U8: return 1
		PandaGeom.NumericType.U16: return 2
		PandaGeom.NumericType.U32: return 4
		PandaGeom.NumericType.S8: return 1
		PandaGeom.NumericType.S16: return 2
		PandaGeom.NumericType.S32: return 4
		PandaGeom.NumericType.FLOAT: return 4
		PandaGeom.NumericType.DOUBLE: return 8
		PandaGeom.NumericType.STDFLOAT: return 8 if bam_parser.use_f64_stdfloats else 4
		PandaGeom.NumericType.PACKED_DCBA: return 4
		PandaGeom.NumericType.PACKED_DABC: return 4
		_:
			bam_parser.parse_error('Unknown NumericType')
			return 0

## Returns how many more bytes would remain from a given stride [param remainder]
## after reading a given [param column].
func stride_remainder(remainder: int, column: Dictionary) -> int:
	return remainder - (
		column['num_components'] * 
		_get_byte_offset_for_numeric_type(column['numeric_type'])
	)

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
	var old_read_info = bam_parser.swap_read_contents(buffer)
	var active_columns: Dictionary
	
	# Store a list of transformed mesh data.
	var data = {
		'vertices': PackedVector3Array(),
		'indexes': [],
		'texcoords': PackedVector2Array(),
		'normals': PackedVector3Array(),
		'colors': PackedColorArray(),
		'transform_blend_indexes': [],
		# Panda3D stores tangents and binormals separately, whereas Godot
		# stores them together. Thus we'll keep track of them separately here,
		# but recalculate them at the end if we receive any values.
		'ptangents': PackedVector3Array(),
		'binormals': PackedVector3Array(),
	}
	
	for column in o_array_format.o_columns:
		column['numeric_type_decoder'] = _get_decoder_for_numeric_type(column['numeric_type'])
	
	# We will now begin to read the byte array containing our mesh data.
	#
	# The o_array_format (PandaGeomVertexArrayFormat) tells us how to read the
	# incoming byte array. In essence, the data contains multiple "columns" that
	# are interlaced. So, if you have three columns (A, B, C), you'd take turns
	# reading data from each of them: A -> B -> C -> A -> B -> C.
	#
	# This continues until the byte array is out of data. Each loop should have
	# a set length known as a "stride", and we can use that to ensure we haven't
	# lost our place / gotten offset in the byte array.
	while bam_parser.datagram_size_remaining > 0:
		# We keep track of "active" columns every read... theoretically it's
		# possible for columns to start being interlaced later on, I think...
		active_columns.clear()
		bam_parser.ensure(
			o_array_format.stride <= bam_parser.datagram_size_remaining,
			("GeomVertexArrayFormat's (%s) stride is bigger than our " +
				"remaining datagram size (%s > %s)") %
				[
					o_array_format.object_id,
					o_array_format.stride, 
					bam_parser.datagram_size_remaining
				]
		)
		var stride_goal := bam_parser.read_byte_offset + o_array_format.stride
		# Find our active columns this stride.
		for column in o_array_format.o_columns:
			# In case a new column takes precent over old one (?)
			# TODO: This is broken anyway, column start is relative and stride_goal is cumulating the byte offset
			if stride_goal >= column['start']:
				active_columns[column['name'].name] = column
		
		# Let's start reading each column for this stride.
		var column: Dictionary
		for column_name in active_columns.keys():
			column = active_columns[column_name]
			match column['contents']:
				PandaGeom.Contents.POINT:
					data['vertices'].append(
						bam_parser.decode_vector3(column['numeric_type_decoder']) 
						* bam_parser.rotation_matrix
					)
				PandaGeom.Contents.TEXCOORD:
					# Panda3D's UV wrapping on the vertical axis starts at the top
					# and ends at the bottom, which is the opposite of Godot.
					# We'll flip the V coordinate here.
					var texcoords = bam_parser.decode_vector2(column['numeric_type_decoder'])
					texcoords.y = 1 - texcoords.y
					data['texcoords'].append(texcoords)
				PandaGeom.Contents.INDEX:
					var index = column['numeric_type_decoder'].call()
					if column_name == 'transform_blend':
						data['transform_blend_indexes'].append(index)
					else:
						data['indexes'].append(index)
				PandaGeom.Contents.NORMAL:
					data['normals'].append(
						bam_parser.decode_vector3(column['numeric_type_decoder'])
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
					var vector_data = bam_parser.decode_vector3(
						column['numeric_type_decoder']
					)  
					if column_name == 'tangent':
						data['ptangents'].append(vector_data)
					elif column_name == 'binormal':
						data['binormals'].append(vector_data)
				PandaGeom.Contents.COLOR:
					data['colors'].append(column['numeric_type_decoder'].call())
				_:
					var unknown_size: int = _get_byte_offset_for_numeric_type(column['numeric_type']) * column['num_components']
					push_warning('%s Skipping %s bytes of unknown column content...' % [self, unknown_size])
					bam_parser.take_size(unknown_size)

		# Sanity check
		var remainder := stride_goal - bam_parser.read_byte_offset
		if remainder > 0:
			push_warning('%s Skipping %s bytes in stride remainder...' % [self, remainder])
			bam_parser.take_size(remainder)

	bam_parser.unswap_read_contents(old_read_info)
	
	# We're doing reading the byte array! Let's finish up our data dictionary.
	
	# First, if we didn't get any tangent data, erase those two.
	# TODO: Since we erase everything at the bottom anyway, this is redundant.
	if not data['ptangents'] or not data['binormals']:
		data.erase('ptangents')
		data.erase('binormals')
	else:
		# We must calculate the directional signs of the binormals.
		var tangents = PackedFloat32Array()
		bam_parser.ensure(
			data['ptangents'].size() == data['binormals'].size(),
			"The size of the tangents and binormal arrays do not match (%s != %s)" %
				[data['ptangents'].size(), data['binormals'].size()]
		)
		bam_parser.ensure(
			data['ptangents'].size() == data['normals'].size(),
			"The size of the tangents and normal arrays do not match (%s != %s)" %
				[data['ptangents'].size(), data['normals'].size()]
		)
		for i in range(data['ptangents'].size()):
			var normal: Vector3 = data['normals'][i]
			var tangent: Vector3 = data['ptangents'][i]
			var binormal: Vector3 = data['binormals'][i]
			var calc_binormal = tangent.cross(normal)
			var dot_product = calc_binormal.dot(binormal)
			tangents.append_array(PackedFloat32Array([
				tangent.x, tangent.y, tangent.z, 1.0 if dot_product > 0 else -1.0
			]))
		data['tangents'] = tangents
	
	# Erase any empty entries.
	for key in data.keys():
		if not data[key]:
			data.erase(key)
	
	return data
