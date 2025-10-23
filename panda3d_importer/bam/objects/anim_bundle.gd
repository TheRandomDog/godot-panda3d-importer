extends PandaAnimGroup
class_name PandaAnimBundle

var fps: float
var frame_count: int

func parse_object_data() -> void:
	super()
	fps = datagram.decode_stdfloat()
	frame_count = datagram.decode_u16()
