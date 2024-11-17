extends BamObject
class_name PandaAnimPreloadTable

class AnimRecord:
	var base_name: String
	var base_frame_rate: float
	var num_frames: int

var anims: Array[AnimRecord]

func parse_object_data() -> void:
	var anims_count := bam_parser.decode_u16()
	for i in range(anims_count):
		var record := AnimRecord.new()
		record.base_name = bam_parser.decode_string()
		record.base_frame_rate = bam_parser.decode_stdfloat()
		record.num_frames = bam_parser.decode_s32()
		anims.append(record)
