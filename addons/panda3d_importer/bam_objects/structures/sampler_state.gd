extends RefCounted
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

func parse_data(bam_parser: BamParser):
	wrap_u = bam_parser.decode_u8() as WrapMode
	wrap_v = bam_parser.decode_u8() as WrapMode
	wrap_w = bam_parser.decode_u8() as WrapMode
	minfilter = bam_parser.decode_u8() as FilterType
	magfilter = bam_parser.decode_u8() as FilterType
	anisotropic_degree = bam_parser.decode_u16()
	border_color = bam_parser.decode_color()
	if bam_parser.version >= [6, 36]:
		min_lod = bam_parser.decode_stdfloat()
		max_lod = bam_parser.decode_stdfloat()
		lod_bias = bam_parser.decode_stdfloat()
