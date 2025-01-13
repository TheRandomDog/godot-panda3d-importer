extends BamObject
class_name PandaGeomVertexArrayFormat
## An object describing the format, and how to read, a
## [PandaGeomVertexArrayData] object.

var stride: int
var total_bytes: int
var pad_to: int
var divisor: int = 0
var o_columns: Array[Dictionary]
var column_alignment: int = 1

## Decodes a DirectX style color value from a uint32 (AGBR)
func _decode_dcba() -> Color:
	# These values work but they don't seem to match the documentation
	var vector: Vector4 = bam_parser.decode_vector4(bam_parser.decode_u8)
	return Color(vector.x / 255, vector.y / 255, vector.z / 255, vector.w / 255)

## Decodes a DirectX style color value from a uint32 (ARGB)
func _decode_dabc() -> Color:
	# These values work but they don't seem to match the documentation
	var vector: Vector4 = bam_parser.decode_vector4(bam_parser.decode_u8)
	return Color(vector.z / 255, vector.y / 255, vector.x / 255, vector.w / 255)

## Returns the required [Callable] from [BamParser] to decode a given
## [enum PandaGeom.NumericType].
func get_decoder_for_numeric_type(numeric_type: PandaGeom.NumericType) -> Callable:
	match numeric_type:
		PandaGeom.NumericType.U8: return bam_parser.decode_u8
		PandaGeom.NumericType.U16: return bam_parser.decode_u16
		PandaGeom.NumericType.U32: return bam_parser.decode_u32
		PandaGeom.NumericType.S8: return bam_parser.decode_s8
		PandaGeom.NumericType.S16: return bam_parser.decode_s16
		PandaGeom.NumericType.S32: return bam_parser.decode_s32
		PandaGeom.NumericType.FLOAT: return bam_parser.decode_float
		PandaGeom.NumericType.DOUBLE: return bam_parser.decode_double
		PandaGeom.NumericType.STDFLOAT: return bam_parser.decode_stdfloat
		PandaGeom.NumericType.PACKED_DCBA: return _decode_dcba
		PandaGeom.NumericType.PACKED_DABC: return _decode_dabc
		_:
			bam_parser.parse_error('Unknown NumericType')
			return func(): pass

## Returns the number of bytes needed to read a
## given [enum PandaGeom.NumericType].
func get_byte_offset_for_numeric_type(numeric_type: PandaGeom.NumericType) -> int:
	match numeric_type:
		PandaGeom.NumericType.U8: return 1
		PandaGeom.NumericType.U16: return 2
		PandaGeom.NumericType.U32: return 4
		PandaGeom.NumericType.S8: return 1
		PandaGeom.NumericType.S16: return 2
		PandaGeom.NumericType.S32: return 4
		PandaGeom.NumericType.FLOAT: return 4
		PandaGeom.NumericType.DOUBLE: return 8
		PandaGeom.NumericType.STDFLOAT: return 8 if bam_parser.use_f64_stdfloats else 4
		PandaGeom.NumericType.PACKED_DCBA: return 4
		PandaGeom.NumericType.PACKED_DABC: return 4
		_:
			bam_parser.parse_error('Unknown NumericType')
			return 0

func parse_object_data() -> void:
	stride = bam_parser.decode_u16()
	total_bytes = bam_parser.decode_u16()
	pad_to = bam_parser.decode_u8()
	if bam_parser.version >= [6, 37]:
		divisor = bam_parser.decode_u16()
	var columns_count := bam_parser.decode_u16()
	for i in range(columns_count):
		var data := {
			'name': bam_parser.decode_and_follow_pointer() as PandaInternalName,
			'num_components': bam_parser.decode_u8(),
			'numeric_type': bam_parser.decode_u8() as PandaGeom.NumericType,
			'contents': bam_parser.decode_u8() as PandaGeom.Contents,
			'start': bam_parser.decode_u16(),
		}
		data.merge({
			'numeric_type_decoder': get_decoder_for_numeric_type(data['numeric_type']),
			'size': data['num_components'] * get_byte_offset_for_numeric_type(data['numeric_type'])
		})
		if bam_parser.version >= [6, 29]:
			data['alignment'] = bam_parser.decode_u8()
		
		o_columns.append(data)
