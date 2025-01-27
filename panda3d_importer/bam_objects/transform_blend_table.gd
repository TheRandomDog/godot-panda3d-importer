extends BamObject
class_name PandaTransformBlendTable
## A BAM Object containing an array of transform blends (typically 
## weights for joints/bones).

var o_blends: Array[PandaTransformBlend]
var rows: PandaSparseArray
var use_eight_bone_weights := false

func parse_object_data() -> void:
	var blend_count := bam_parser.decode_u16()
	o_blends.resize(blend_count)
	for i in range(blend_count):
		var blend := PandaTransformBlend.new()
		blend.parse_data(bam_parser)
		var blend_entries_size := blend.entries.size()
		if blend_entries_size > 4:
			if blend_entries_size > 8:
				match configuration['excess_transform_blend_behavior']:
					ParserConfigs.BAMExcessTransformBlendBehavior.WARN_AND_DROP:
						bam_parser.parse_warning(
							('TransformBlend has more than 8 weights (%s)' % blend_entries_size) +
							', dropping least significant blends...'
						)
						while blend.entries.size() > 8:
							blend.entries.pop_front()
					ParserConfigs.BAMExcessTransformBlendBehavior.DROP:
						while blend.entries.size() > 8:
							blend.entries.pop_front()
					_:
						bam_parser.parse_error(
							'TransformBlend has more than 8 weights (%s)' % blend_entries_size
						)
			use_eight_bone_weights = true
		o_blends[i] = blend
	
	if bam_parser.version >= [6, 7]:
		rows = PandaSparseArray.new()
		rows.parse_data(bam_parser)
	# TODO: If bam_parser.version < [6, 7], PandaGeomVertexData must create
	# a PandaSparseArray to populate `rows` for us.
