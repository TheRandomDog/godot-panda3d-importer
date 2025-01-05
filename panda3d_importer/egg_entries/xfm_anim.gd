extends EggAnimBase
class_name EggMatrixAnim

var column_contents: String
var order := 'srpht'

func read_values(values_string: String) -> void:
	var all_values = get_floats(values_string)
	#bam_parser.ensure(
	#	all_values.size() % column_contents.length() == 0,
	#	"The total number of animation values was not divisible by the " +
	#		"number of columns (%s % %s != 0)" % [all_values.size(), column_contents.length()]
	#)
	var num_columns = column_contents.length()
	var num_frames = all_values.size() / num_columns
	for i in range(num_columns):
		var column = column_contents[i]
		var column_values = PackedFloat64Array()
		column_values.resize(num_frames)
		for frame in range(num_frames):
			column_values[frame] = all_values[(num_frames * i) - (num_frames - frame)]

func read_scalar(scalar: String, data: String) -> void:
	super(scalar, data)
	match scalar:
		'order':
			order = data
		'contents':
			column_contents = data

func _get_values_frame(frame: int, columns: String, default:=0.0) -> Dictionary:
	var resp: Dictionary
	for column in columns:
		var value: float
		match values.get(column, []).size():
			0:
				value = default
			1:
				value = values[column][0]
			_:
				value = values[column][frame]
		resp[column] = value
	return resp
	
func _get_euler_order() -> int:
	#if 'rph' in order or not ('h' in order and 'p' in order and 'r' in order):
	return EULER_ORDER_YXZ
	
func get_animation_data() -> Dictionary:
	var data = {
		'position': PackedVector3Array(),
		'rotation': Array(),
		'scale': PackedVector3Array(),
	}
	for frame in range(frame_count):
		if 'x' in values or 'y' in values or 'z' in values:
			var p = _get_values_frame(frame, 'xyz')
			data['position'].append(
				Vector3(p['x'], p['y'], p['z']) * egg_parser.rotation_matrix
			)
		if 'h' in values or 'p' in values or 'r' in values:
			var r = _get_values_frame(frame, 'hpr')
			var basis = Panda2Godot.get_basis_from_hpr(
				Vector3(r['h'], r['p'], r['r'])
			)
			data['rotation'].append(Quaternion(basis))
		if 'i' in values or 'j' in values or 'k' in values:
			# TODO: Probably need to apply rotation matrix to scale as well
			var s = _get_values_frame(frame, 'ijk', 1.0)
			data['scale'].append(Vector3(s['i'], s['j'], s['k']))
	return data
