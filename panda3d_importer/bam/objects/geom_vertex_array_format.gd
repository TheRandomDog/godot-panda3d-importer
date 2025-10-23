extends BamObject
class_name PandaGeomVertexArrayFormat
## An object describing the format, and how to read, a
## [PandaGeomVertexArrayData] object.

var stride: int
var total_bytes: int
var pad_to: int
var divisor: int = 0
var _columns: Array[Dictionary]
var column_alignment: int = 1

func get_columns() -> Array[Dictionary]:
	var columns: Array[Dictionary]
	for column in _columns:
		columns.append(column.duplicate())
		columns[-1].name = get_object(columns[-1].name)
	return columns

## Returns the required [PandaDatagramReader] method name to decode a given
## [enum PandaGeom.NumericType].
func get_decoder_for_numeric_type(numeric_type: PandaGeom.NumericType) -> StringName:
	match numeric_type:
		PandaGeom.NumericType.U8: return &"decode_u8"
		PandaGeom.NumericType.U16: return &"decode_u16"
		PandaGeom.NumericType.U32: return &"decode_u32"
		PandaGeom.NumericType.S8: return &"decode_s8"
		PandaGeom.NumericType.S16: return &"decode_s16"
		PandaGeom.NumericType.S32: return &"decode_s32"
		PandaGeom.NumericType.FLOAT: return &"decode_float"
		PandaGeom.NumericType.DOUBLE: return &"decode_double"
		PandaGeom.NumericType.STDFLOAT: return &"decode_stdfloat"
		PandaGeom.NumericType.PACKED_DCBA: return &"decode_color_dcba"
		PandaGeom.NumericType.PACKED_DABC: return &"decode_color_dabc"
		_:
			bam_parser.parse_error('Unknown NumericType')
			return StringName()

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
	stride = datagram.decode_u16()
	total_bytes = datagram.decode_u16()
	pad_to = datagram.decode_u8()
	if bam_parser.version >= [6, 37]:
		divisor = datagram.decode_u16()
	var columns_count := datagram.decode_u16()
	for i in range(columns_count):
		var data := {
			name = datagram.next_object_ref(PandaInternalName),
			num_components = datagram.decode_u8(),
			numeric_type = datagram.decode_u8() as PandaGeom.NumericType,
			contents = datagram.decode_u8() as PandaGeom.Contents,
			start = datagram.decode_u16(),
		}
		data.merge({
			numeric_type_decoder = \
				get_decoder_for_numeric_type(data.numeric_type),
			size = (
				data.num_components
				* get_byte_offset_for_numeric_type(data.numeric_type)
			)
		})
		if bam_parser.version >= [6, 29]:
			data.alignment = datagram.decode_u8()

		_columns.append(data)
