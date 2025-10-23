extends PandaMovingPartBase
class_name PandaMovingPartMatrix

var value: Projection
var default_value: Projection

func parse_object_data() -> void:
	super()
	value = datagram.decode_projection()
	default_value = datagram.decode_projection()
