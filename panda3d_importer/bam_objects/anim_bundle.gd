extends PandaAnimGroup
class_name PandaAnimBundle

var fps: float
var frame_count: int

func parse_object_data() -> void:
	super()
	fps = bam_parser.decode_stdfloat()
	frame_count = bam_parser.decode_u16()
