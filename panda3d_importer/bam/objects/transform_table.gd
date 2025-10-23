extends BamObject
class_name PandaTransformTable

var _transforms: Array[WeakRef]
func get_transforms() -> Array[PandaVertexTransform]:
	var array: Array[PandaVertexTransform]
	array.assign(get_objects_from_array(_transforms))
	return array

func parse_object_data() -> void:
	_transforms = datagram.next_object_ref_array(PandaVertexTransform)
