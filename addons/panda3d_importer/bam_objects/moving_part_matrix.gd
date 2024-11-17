extends PandaMovingPartBase
class_name PandaMovingPartMatrix

var value: Projection
var default_value: Projection

func parse_object_data() -> void:
	super()
	value = bam_parser.decode_projection()
	default_value = bam_parser.decode_projection()
