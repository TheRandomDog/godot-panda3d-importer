extends PandaNode
class_name PandaPartBundleNode
## A PandaNode that holds pointers to child [PandaPartBundle] objects.

var o_bundles: Array[PandaPartBundle]

func parse_object_data() -> void:
	super()
	var bundles_count := bam_parser.decode_u16()
	for i in range(bundles_count):
		o_bundles.append(bam_parser.decode_and_follow_pointer() as PandaPartBundle)
