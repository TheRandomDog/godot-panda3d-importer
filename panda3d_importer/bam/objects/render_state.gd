extends BamObject
class_name PandaRenderState
## A required child object of PandaNode that describes how it's rendered.
##
## PandaRenderAttribs are only applied in Panda3D when they encounter a GeomNode
## child (containing geometry).

var _attribs: Array[WeakRef]
func get_attribs() -> Array[PandaRenderAttrib]:
	var array: Array[PandaRenderAttrib]
	array.assign(get_objects_from_array(_attribs))
	return array

var attrib_overrides: Array[int]

func _decode_attrib_override(_i: int, _attrib: WeakRef) -> void:
	attrib_overrides.append(datagram.decode_s32())

func parse_object_data() -> void:
	_attribs = datagram.next_object_ref_array_and_extra(
		_decode_attrib_override, PandaRenderAttrib
	)
