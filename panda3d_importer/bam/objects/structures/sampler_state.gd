extends BAMStruct
class_name SamplerState

enum FilterType {
	NEAREST,
	LINEAR,
	NEAREST_MIPMAP_NEAREST,
	LINEAR_MIPMAP_NEAREST,
	NEAREST_MIPMAP_LINEAR,
	LINEAR_MIPMAP_LINEAR,
	SHADOW,
	DEFAULT,
	INVALID,
}
enum WrapMode { CLAMP, REPEAT, MIRROR, MIRROR_ONCE, BORDER_COLOR, INVALID }

var wrap_u: WrapMode
var wrap_v: WrapMode
var wrap_w: WrapMode
var minfilter: FilterType
var magfilter: FilterType
var anisotropic_degree: int
var border_color: Color
var min_lod: float = -1000
var max_lod: float = 1000
var lod_bias: float = 0

func _init(datagram: PandaBAMDatagramReader) -> void:
	wrap_u = datagram.decode_u8() as WrapMode
	wrap_v = datagram.decode_u8() as WrapMode
	wrap_w = datagram.decode_u8() as WrapMode
	minfilter = datagram.decode_u8() as FilterType
	magfilter = datagram.decode_u8() as FilterType
	anisotropic_degree = datagram.decode_u16()
	border_color = datagram.decode_color()
	if datagram.get_parser().version >= [6, 36]:
		min_lod = datagram.decode_stdfloat()
		max_lod = datagram.decode_stdfloat()
		lod_bias = datagram.decode_stdfloat()
