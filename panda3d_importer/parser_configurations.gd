extends Object
class_name ParserConfigs

enum BAMExcessTransformBlendBehavior { ERROR, WARN_AND_DROP, DROP }

static func get_bam_parser_configuration() -> Dictionary:
	return {
		'parser': {
			'make_sprite_scale': Vector2(1, 1),
		},
		PandaAnimBundleNode: {
			'loop_mode': Animation.LoopMode.LOOP_NONE,
		},
		PandaTransformBlendTable: {
			'excess_transform_blend_behavior': BAMExcessTransformBlendBehavior.ERROR,
		},
	}
