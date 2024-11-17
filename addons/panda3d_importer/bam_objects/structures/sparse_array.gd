extends RefCounted
class_name PandaSparseArray

class Subrange:
	var begin: int
	var end: int

var subranges: Array[Subrange]
var inverse: bool

func parse_data(bam_parser: BamParser):
	var subranges_count = bam_parser.decode_u32()
	subranges.resize(subranges_count)
	for i in range(subranges_count):
		var subrange = Subrange.new()
		subrange.begin = bam_parser.decode_s32()
		subrange.end = bam_parser.decode_s32()
		subranges[i] = subrange
	inverse = bam_parser.decode_bool()
