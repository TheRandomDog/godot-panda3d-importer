extends PandaPartGroup
class_name PandaMovingPartBase

var _forced_channel: WeakRef = null  # 6.20+
var forced_channel: PandaAnimChannelBase:  # 6.20+
	get:
		return get_object(_forced_channel)

func parse_object_data() -> void:
	super()
	if bam_parser.version >= [6, 20]:
		_forced_channel = datagram.next_object_ref_or_null(PandaAnimChannelBase)
