extends PandaAnimChannelBase
class_name PandaAnimChannelMatrixXfmTable
## An animation channel whose data is stored as per-frame per-component values. 

const NUM_MATRIX_COMPONENTS := 12
var tables: Array[PackedFloat32Array]
var frame_count: int

var has_scale_data := false
var has_shear_data := false
var has_position_data := false
var has_rotation_data := false

func parse_object_data() -> void:
	super()
	
	# TODO: It may be possible to read FFT compressed channels, but as this is
	# currently deprecated in Panda3D, it doesn't seem worth the hassle.
	var compressed_channels = bam_parser.decode_bool()
	bam_parser.ensure(!compressed_channels, "Compressed animation channels cannot be read")
	
	# TODO: On the other hand, this can be done, it's just a TODO item.
	var new_hpr = bam_parser.decode_bool()
	bam_parser.ensure(new_hpr, "Old HPR for animation channels cannot be read yet")
	
	# The order of matrix components are:
	# 0, 1, 2 - Scale
	# 3, 4, 5 - Shear (unused at the time being)
	# 6, 7, 8 - HPR Rotation
	# 9,10,11 - Position
	#
	# We are going to store each component's frame data into a PackedFloat32Array.
	for i in range(NUM_MATRIX_COMPONENTS):
		var count := bam_parser.decode_u16()  # Number of frames for this component
		var table: PackedFloat32Array
		table.resize(count)
		if count:
			# The number of frames should either match the other components,
			# or just be one unchanged value (for BAM file size efficiency).
			if count > frame_count:
				frame_count = count
			bam_parser.ensure(
				frame_count == count or count == 1,
				"Received a count value (%s) that was not frame_count (%s) or 1" %
					[count, frame_count]
			)
			if i < 3:
				has_scale_data = true
			elif i < 6:
				has_shear_data = true
			elif i < 9:
				has_rotation_data = true
			elif i < 12:
				has_position_data = true
		for j in range(count):
			table[j] = bam_parser.decode_stdfloat()
		tables.append(table)

## Returns the value of a matrix component at a given frame, or a default value.
func _get_table_frame(frame: int, index: int, default: float) -> float:
	match tables[index].size():
		0:
			return default
		1:
			return tables[index][0]
		_:
			return tables[index][frame]

## Returns a Vector3 containing the value of a transform type at a given frame 
## (by giving the starting index of the first related component). If no data
## exists for a specific component, a default value can/will be returned instead.
## [br][br]
## begin = 0->Scale, 3->Shear, 6->Rotation, 9->Position
func _get_table_slice(frame: int, begin: int, default:=0.0) -> Vector3:
	var x := _get_table_frame(frame, begin, default)
	var y := _get_table_frame(frame, begin + 1, default)
	var z := _get_table_frame(frame, begin + 2, default)
	return Vector3(x, y, z)

## Returns a Dictionary containing animation data suitable for Godot's Animation
## resource. The Dictionary will be formatted like:
##
## [codeblock]{
##     "position": PackedVector3Array(),
##     "rotation": Array(),  # An array of quaternions
##     "scale": PackedVector3Array(),
## }[/codeblock]
func get_animation_data() -> Dictionary:
	var data := {
		'position': PackedVector3Array(),
		'rotation': Array(),
		'scale': PackedVector3Array(),
	}
	for frame in range(frame_count):
		if has_position_data:
			data['position'].append(
				_get_table_slice(frame, 9) * bam_parser.rotation_matrix
			)
		if has_rotation_data:
			var basis = Panda2Godot.get_basis_from_hpr(_get_table_slice(frame, 6))
			data['rotation'].append(Quaternion(basis))
		if has_scale_data:
			data['scale'].append(Vector3(
				_get_table_frame(frame, 0, 1.0),
				_get_table_frame(frame, 2, 1.0),
				_get_table_frame(frame, 1, 1.0)
			))  # Manually switch Y and Z here, as this isn't a rotation
	return data
