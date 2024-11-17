extends PandaAnimGroup
class_name PandaAnimChannelBase

## The value of the last frame. May be unused, frequently gets set to UINT16_MAX.
var last_frame: int

func parse_object_data() -> void:
	super()
	last_frame = bam_parser.decode_u16()

## Returns a Dictionary containing animation data suitable for Godot's Animation
## resource. The Dictionary will be formatted like:
##
## [codeblock]{
##     "position": PackedVector3Array(),
##     "rotation": Array(),  # An array of quaternions
##     "scale": PackedVector3Array(),
## }[/codeblock]
func get_animation_data() -> Dictionary[String, Variant]:
	return {
		'position': PackedVector3Array(),
		'rotation': Array(),
		'scale': PackedVector3Array(),
	}
