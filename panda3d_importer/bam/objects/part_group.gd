extends BamObject
class_name PandaPartGroup
## The base BAM Object that defines a heirarchy of [PandaMovingPart] objects
## (typically, a skeleton).

var name: String

var _children: Array[WeakRef]
func get_children() -> Array[PandaPartGroup]:
	var array: Array[PandaPartGroup]
	array.assign(get_objects_from_array(_children))
	return array

func parse_object_data() -> void:
	name = datagram.decode_string()
	if bam_parser.version == [6, 11]:
		# Old freeze-joint information that's no longer relevant
		datagram.decode_bool()
		datagram.decode_projection()
	_children = datagram.next_object_ref_array(PandaPartGroup)
