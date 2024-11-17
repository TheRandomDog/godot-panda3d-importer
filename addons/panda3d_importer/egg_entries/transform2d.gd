extends EggEntry
class_name EggTransform2D

var transform: Transform2D
	
func read_child(child: Dictionary) -> void:
	match child['type']:
		'Translate':
			transform = transform.translated(EggEntry.as_vector2(child))
		'Rotate':
			transform = transform.rotated(
				deg_to_rad(EggEntry.as_float(child))
			)
		'Scale':
			transform = transform.scaled(EggEntry.as_vector2(child))
		'Matrix3':
			var values: PackedFloat64Array = EggEntry.get_floats(
				contents(), 9, false
			)
			var matrix := Transform2D(
				Vector2(values[0], values[1]),
				Vector2(values[3], values[4]),
				Vector2(values[6], values[7])
			)
			transform *= matrix
