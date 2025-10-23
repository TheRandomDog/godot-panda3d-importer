extends BamObject
class_name PandaGeomVertexFormat

var animation_type: PandaGeom.AnimationType
var num_transforms: int = 0
var indexed_transforms: bool = false

var _arrays: Array[WeakRef]
func get_arrays() -> Array[PandaGeomVertexArrayFormat]:
	var array: Array[PandaGeomVertexArrayFormat]
	array.assign(get_objects_from_array(_arrays))
	return array

func parse_object_data() -> void:
	animation_type = datagram.decode_u8() as PandaGeom.AnimationType
	num_transforms = datagram.decode_u16()
	indexed_transforms = datagram.decode_bool()
	_arrays = datagram.next_object_ref_array(PandaGeomVertexArrayFormat)
