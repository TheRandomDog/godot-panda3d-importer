extends BamObject
class_name PandaAnimPreloadTable

var anims: Array[AnimRecord]

func parse_object_data() -> void:
	anims.assign(BAMStruct.make_array(AnimRecord, datagram))


class AnimRecord extends BAMStruct:
	var base_name: String
	var base_frame_rate: float
	var num_frames: int

	func _init(datagram: PandaBAMDatagramReader) -> void:
		base_name = datagram.decode_string()
		base_frame_rate = datagram.decode_stdfloat()
		num_frames = datagram.decode_s32()
