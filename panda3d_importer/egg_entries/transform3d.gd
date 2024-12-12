extends EggEntry
class_name EggTransform3D

var transform: Transform3D

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Translate':
			transform = transform.translated(EggEntry.as_vector3(child))
		'Rotate':
			pass  # TODO
			#transform = transform.rotated(
			#	deg_to_rad(EggEntry.as_float(child))
			#)
		'Scale':
			transform = transform.scaled(EggEntry.as_vector3(child))
		'Matrix4':
			transform *= Transform3D(EggEntry.as_projection(child))
