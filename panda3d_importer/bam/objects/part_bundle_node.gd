extends PandaNode
class_name PandaPartBundleNode
## A PandaNode that holds pointers to child [PandaPartBundle] objects.

var _bundles: Array[WeakRef]
func get_bundles() -> Array[PandaPartBundle]:
	var array: Array[PandaPartBundle]
	array.assign(get_objects_from_array(_bundles))
	return array

func parse_object_data() -> void:
	super()
	_bundles = datagram.next_object_ref_array(PandaPartBundle)
