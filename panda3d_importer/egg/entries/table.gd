extends EggEntry
class_name EggTable

var tables: Array[EggTable]
var bundles: Array[EggBundle]
var scalar_anims: Array[EggScalarAnim]
var matrix_anims: Array[EggMatrixAnim]
var hybrid_anims: Array[EggHybridAnim]
var vertex_anims

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Table':
			tables.append(EggTable.new(egg_parser, child))
		'Bundle':
			bundles.append(EggBundle.new(egg_parser, child))
		'S$Anim':
			scalar_anims.append(EggScalarAnim.new(egg_parser, child))
		'Xfm$Anim':
			matrix_anims.append(EggMatrixAnim.new(egg_parser, child))
		'Xfm$Anim_S$':
			hybrid_anims.append(EggHybridAnim.new(egg_parser, child))
		'VertexAnim':
			pass#vertex_anims.append(EggAnim.new(egg_parser, child))

func get_frame_count() -> int:
	# TODO
	if hybrid_anims:
		return hybrid_anims[0].frame_count
	return 0

func get_fps() -> float:
	# TODO
	if hybrid_anims:
		return hybrid_anims[0].fps
	return 0

func get_animation_data() -> Dictionary:
	# TODO
	if hybrid_anims:
		return hybrid_anims[0].get_animation_data()
	return {}
