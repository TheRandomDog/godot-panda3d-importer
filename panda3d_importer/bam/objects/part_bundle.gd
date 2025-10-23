extends PandaPartGroup
class_name PandaPartBundle
# TODO

enum BlendType {
	LINEAR,
	NORMALIZED_LINEAR,
	COMPONENTWISE,
	COMPONENTWISE_QUAT,
}

var _anim_preload: WeakRef  # 6.17+
var anim_preload: PandaAnimPreloadTable:  # 6.17+
	get:
		return get_object(_anim_preload)

var blend_type: BlendType  # 6.10+
var anim_blend_flag: bool  # 6.10+
var frame_blend_flag: bool  # 6.10+
var root_xform: Projection  # 6.10+
var _old_modifies_anim_bundles: bool  # 6.11 only

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 17]:
		_anim_preload = datagram.next_object_ref_or_null(PandaAnimPreloadTable)
	if bam_parser.version >= [6, 10]:
		blend_type = datagram.decode_u8() as BlendType
		anim_blend_flag = datagram.decode_bool()
		frame_blend_flag = datagram.decode_bool()
		root_xform = datagram.decode_projection()
	if bam_parser.version == [6, 11]:
		_old_modifies_anim_bundles = datagram.decode_bool()
