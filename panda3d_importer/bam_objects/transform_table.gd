extends BamObject
class_name PandaTransformTable

var o_transforms: Array[PandaVertexTransform]

func parse_object_data() -> void:
	var transform_count := bam_parser.decode_u16()
	o_transforms.resize(transform_count)
	for i in range(transform_count):
		var transform := bam_parser.decode_and_follow_pointer() as PandaVertexTransform
		o_transforms[i] = transform
