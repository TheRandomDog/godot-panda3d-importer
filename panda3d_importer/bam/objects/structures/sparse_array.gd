extends BAMStruct
class_name PandaSparseArray

var subranges: Array[Subrange]
var inverse: bool

func _init(datagram: PandaBAMDatagramReader) -> void:
	subranges.assign(BAMStruct.make_array(Subrange, datagram, datagram.decode_u32))
	inverse = datagram.decode_bool()


class Subrange extends BAMStruct:
	var begin: int
	var end: int

	func _init(datagram: PandaBAMDatagramReader) -> void:
		begin = datagram.decode_s32()
		end = datagram.decode_s32()
