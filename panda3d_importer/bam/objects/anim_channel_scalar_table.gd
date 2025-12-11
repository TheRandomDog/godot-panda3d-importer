extends PandaAnimChannelBase
class_name PandaAnimChannelScalarTable

const NUM_MATRIX_COMPONENTS := 12
var frame_count: int
var table: PackedFloat32Array

var has_scale_data := false
var has_shear_data := false
var has_position_data := false
var has_rotation_data := false

func parse_object_data() -> void:
	super()

	# It may be possible to read FFT compressed channels, but as this is
	# currently deprecated in Panda3D, it doesn't seem worth the hassle.
	var compressed_channels = datagram.decode_bool()
	bam_parser.ensure(
		not compressed_channels,
		"Compressed animation channels cannot be read"
	)

	frame_count = datagram.decode_u16()
	table.resize(frame_count)
	for i in frame_count:
		table[i] = datagram.decode_stdfloat()

## Returns a Dictionary containing animation data suitable for Godot's Animation
## resource. The Dictionary will be formatted like:
##
## [codeblock]{
##     "position": PackedVector3Array(),
##     "rotation": Array(),  # An array of quaternions
##     "scale": PackedVector3Array(),
## }[/codeblock]
func get_animation_data() -> Dictionary:
	return {'scalar': table}
