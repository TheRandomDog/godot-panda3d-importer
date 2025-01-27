extends Object
class_name ParserConfigs

static func get_bam_parser_configuration() -> Dictionary:
	return {
		PandaAnimBundleNode: {
			'loop_mode': Animation.LoopMode.LOOP_NONE,
		},
	}
