extends PandaMovingPartBase
class_name PandaMovingPartScalar

var value: float
var default_value: float

func parse_object_data() -> void:
	super()
	value = datagram.decode_stdfloat()
	default_value = datagram.decode_stdfloat()
