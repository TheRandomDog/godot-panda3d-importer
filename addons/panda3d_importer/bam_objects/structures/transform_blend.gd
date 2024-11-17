extends RefCounted
class_name PandaTransformBlend
## A data class containing weight data for transform blends (typically for joints/bones).

class TransformEntry:
	var transform: PandaVertexTransform
	var weight: float

var entries: Array[TransformEntry]

func parse_data(bam_parser: BamParser):
	var entries_count := bam_parser.decode_u16()
	entries.resize(entries_count)
	for i in range(entries_count):
		var entry := TransformEntry.new()
		entry.transform = bam_parser.decode_and_follow_pointer() as PandaVertexTransform
		entry.weight = bam_parser.decode_stdfloat()
		entries[i] = entry
	entries.sort_custom(func(a: TransformEntry, b: TransformEntry): return a.weight < b.weight)
