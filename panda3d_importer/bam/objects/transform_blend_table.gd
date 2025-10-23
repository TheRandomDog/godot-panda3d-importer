extends BamObject
class_name PandaTransformBlendTable
## A BAM Object containing an array of transform blends (typically
## weights for joints/bones).

var blends: Array[PandaTransformBlend]
var rows: PandaSparseArray
var use_eight_bone_weights := false

func _check_blend_entries_size(_i: int, blend: PandaTransformBlend) -> void:
	var blend_entries_size := blend.entries.size()
	if blend_entries_size > 4:
		if blend_entries_size > 8:
			match configuration.excess_transform_blend_behavior:
				BAMParserConfigs.BAMExcessTransformBlendBehavior.WARN_AND_DROP:
					bam_parser.parse_warning(
						('TransformBlend has more than 8 weights (%s)' % blend_entries_size) +
						', dropping least significant blends...'
					)
					while blend.entries.size() > 8:
						blend.entries.pop_front()
				BAMParserConfigs.BAMExcessTransformBlendBehavior.DROP:
					while blend.entries.size() > 8:
						blend.entries.pop_front()
				_:
					bam_parser.parse_error(
						'TransformBlend has more than 8 weights (%s)' % blend_entries_size
					)
		use_eight_bone_weights = true

func parse_object_data() -> void:
	blends.assign(BAMStruct.make_array_and_extra(
		_check_blend_entries_size, PandaTransformBlend, datagram
	))
	if bam_parser.version >= [6, 7]:
		rows = PandaSparseArray.new(datagram)
	# TODO: If bam_parser.version < [6, 7], PandaGeomVertexData must create
	# a PandaSparseArray to populate `rows` for us.
