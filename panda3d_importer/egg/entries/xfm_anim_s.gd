extends EggMatrixAnim
class_name EggHybridAnim

func read_child(child: Dictionary) -> void:
	super(child)
	match child['type']:
		'S$Anim':
			var scalar_anim := EggScalarAnim.new(egg_parser, child)
			var column := scalar_anim.name()
			column_contents += column
			values[column] = scalar_anim.values['scalar']
			set_frame_count()
