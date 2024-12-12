extends PandaPartGroup
class_name PandaPartBundle
# TODO

enum BlendType { LINEAR, NORMALIZED_LINEAR, COMPONENTWISE, COMPONENTWISE_QUAT }

var o_anim_preload: PandaAnimPreloadTable  # 6.17+
var blend_type: BlendType  # 6.10+
var anim_blend_flag: bool  # 6.10+
var frame_blend_flag: bool  # 6.10+
var root_xform: Projection  # 6.10+
var _old_modifies_anim_bundles: bool  # 6.11 only

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 17]:
		o_anim_preload = bam_parser.decode_and_follow_pointer(true) as PandaAnimPreloadTable
	if bam_parser.version >= [6, 10]:
		blend_type = bam_parser.decode_u8() as BlendType
		anim_blend_flag = bam_parser.decode_bool()
		frame_blend_flag = bam_parser.decode_bool()
		root_xform = bam_parser.decode_projection()
	if bam_parser.version == [6, 11]:
		_old_modifies_anim_bundles = bam_parser.decode_bool()
