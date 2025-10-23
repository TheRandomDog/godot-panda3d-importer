extends BamObject
class_name PandaAnimGroup

var name: String

var _root: WeakRef
var root: PandaAnimBundle:
	get:
		return get_object(_root)

var _children: Array[WeakRef]
func get_children() -> Array[PandaAnimGroup]:
	var array: Array[PandaAnimGroup]
	array.assign(get_objects_from_array(_children))
	return array

func parse_object_data() -> void:
	name = datagram.decode_string()
	_root = datagram.next_object_ref(PandaAnimBundle)
	_children = datagram.next_object_ref_array(PandaAnimGroup)
