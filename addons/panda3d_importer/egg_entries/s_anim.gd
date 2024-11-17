extends EggAnimBase
class_name EggScalarAnim

func read_values(values_string: String) -> void:
	values['scalar'] = get_floats(values_string)
