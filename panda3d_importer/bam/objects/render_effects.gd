extends BamObject
class_name PandaRenderEffects
## A required child object of PandaNode that describes how it's rendered.
##
## PandaRenderEffects are not limited to geometry and will be applied to any
## PandaNode.

var _effects: Array[WeakRef]
func get_effects() -> Array[PandaRenderEffect]:
	var array: Array[PandaRenderEffect]
	array.assign(get_objects_from_array(_effects))
	return array

func parse_object_data() -> void:
	_effects = datagram.next_object_ref_array(PandaRenderEffect)
