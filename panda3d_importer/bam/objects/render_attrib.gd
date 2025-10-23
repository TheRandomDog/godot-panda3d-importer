extends BamObject
class_name PandaRenderAttrib
## The base object for render attributes, changing how any applicable GeomNode
## (specifically geometry) is rendered.

func parse_object_data() -> void:
	pass

func apply_to_surface(surface: Surface) -> void:
	pass
