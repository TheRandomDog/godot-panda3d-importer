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
		if blend.entries.size() > 4:
			bam_parser.ensure(blend.entries.size() <= 8, 'TransformBlend has more than 8 weights')
			use_eight_bone_weights = true
		o_blends[i] = blend
	
	if bam_parser.version >= [6, 7]:
		rows = PandaSparseArray.new()
		rows.parse_data(bam_parser)
	# TODO: If bam_parser.version < [6, 7], PandaGeomVertexData must create
	# a PandaSparseArray to populate `rows` for us.
