extends PandaNode
class_name PandaCollisionNode

var solids
var collision_mask: int

func parse_object_data() -> void:
	return super()
	var solids_count := datagram.decode_count(true)
	for i in range(solids_count):
		datagram.decode_and_follow_pointer()
	collision_mask = datagram.decode_u32()
