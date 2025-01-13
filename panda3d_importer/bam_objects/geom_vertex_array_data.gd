extends BamObject
class_name PandaGeomVertexArrayData
## A byte array containing a subset of vertex data for a geometry mesh.

var o_array_format: PandaGeomVertexArrayFormat
var usage_hint: PandaGeom.UsageHint
var buffer: PackedByteArray

func parse_object_data() -> void:
	o_array_format = bam_parser.decode_and_follow_pointer() as PandaGeomVertexArrayFormat
	usage_hint = bam_parser.decode_u8() as PandaGeom.UsageHint
	var buffer_size := bam_parser.decode_u32()
	buffer = bam_parser.take_size(buffer_size)

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
	
	# We will now begin to read the byte array containing our mesh data.
	#
	# The o_array_format (PandaGeomVertexArrayFormat) tells us how to read the
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
	
	var stride_skip := o_array_format.stride - o_array_format.total_bytes
	
	while bam_parser.datagram_size_remaining > 0:
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
		
		# Let's start reading each column for this stride.
		for column in o_array_format.o_columns:
			var alignment_goal: int = bam_parser.read_byte_offset + column['size']
			
			var column_name: String = column['name'].name
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
					push_warning('%s Skipping %s bytes of unknown column content...' % [self, alignment_goal])
					bam_parser.take_size(alignment_goal)
					
			if bam_parser.read_byte_offset < alignment_goal:
				bam_parser.take_size(alignment_goal - bam_parser.read_byte_offset)
				
		bam_parser.take_size(stride_skip)
		
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
