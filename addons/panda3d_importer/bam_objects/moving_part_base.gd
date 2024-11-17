extends PandaPartGroup
class_name PandaMovingPartBase

var o_forced_channel: PandaAnimChannelBase

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 20]:
		o_forced_channel = bam_parser.decode_and_follow_pointer(true) as PandaAnimChannelBase
