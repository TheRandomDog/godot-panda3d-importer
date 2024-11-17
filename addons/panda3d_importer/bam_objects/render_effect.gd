extends BamObject
class_name PandaRenderEffect
## The base object for render effects, changing how any applicable PandaNode is
## rendered.

func parse_object_data() -> void:
	pass

func apply_to_surface(surface: Surface) -> void:
	pass

func apply_to_node(node: Node3D) -> void:
	pass
