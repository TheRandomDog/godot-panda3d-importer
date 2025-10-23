@tool
class_name PandaDatagramReader
extends RefCounted
## A utility class to manage reading [PackedByteArray]s.
##
## This class is mostly a wrapper around built-in [PackedByteArray]
## functionality, but will push warnings/errors if something goes wrong.

#region Strings
const S_TRUNCATED := "Received truncated datagram"
const S_SIZE_CHECK_FAILED := "Datagram size check failed: %s > %s"
#endregion

var _datagram: PackedByteArray

#region Status
var datagram_size: int
var _datagram_size_with_length: int
var cursor_start: int
var cursor: int
var datagram_size_remaining: int:
	get:
		return max(0, datagram_size - (cursor - cursor_start))
var truncated := false
#endregion

#region Configuration
var _reader_args: Array
var push_errors := true
var use_f64_stdfloats := false
#endregion

static func get_next_datagram_info(
	datagram: PackedByteArray,
	byte_offset: int = 0,
) -> Dictionary:
	var datagram_size_byte_length: int = 4
	var datagram_size := datagram.decode_u32(byte_offset)
	if datagram_size == 0xFFFFFFFF:
		datagram_size_byte_length = 12
		datagram_size = datagram.decode_u64(byte_offset + 4)

	return {
		size = datagram_size,
		size_value_length = datagram_size_byte_length,
		truncated = (
			datagram.size() < datagram_size_byte_length
			or datagram.size() < datagram_size
		),
		excess = max(0, datagram.size() - datagram_size_byte_length - datagram_size - byte_offset)
	}

func _init(
	packed_byte_array: PackedByteArray,
	byte_offset: int = 0,
	args: Array = [],
) -> void:
	_datagram = packed_byte_array
	_reader_args = args
	var size_value_length: int
	if packed_byte_array.is_empty():
		datagram_size = 0
		size_value_length = 0
		truncated = true
	else:
		var datagram_info := get_next_datagram_info(packed_byte_array, byte_offset)
		datagram_size = datagram_info.size
		size_value_length = datagram_info.size_value_length
		#print_debug(packed_byte_array.size(), ' ', datagram_info)
		if datagram_info.truncated:
			truncated = true
			push_error(S_TRUNCATED)

	_datagram_size_with_length = datagram_size + size_value_length
	cursor_start = byte_offset + size_value_length
	reset_cursor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var remaining := datagram_size - (cursor - cursor_start)
		if remaining:
			push_warning(
				'Datagram being freed with %s unread bytes!' % remaining
			)

func reset_cursor() -> void:
	cursor = cursor_start

## Returns [code]true[/code] if there is enough buffer in the datagram to read
## [param length] bytes.
func check_remaining_datagram_size(length: int) -> bool:
	if length <= datagram_size_remaining:
		return true
	if push_errors:
		push_error(S_SIZE_CHECK_FAILED % [length, datagram_size_remaining])
	return false

## Decodes and returns a boolean from the datagram buffer.
func decode_bool() -> bool:
	var value := decode_u8()
	return bool(value)

## Decodes and returns an unsigned int8 from the datagram buffer.
func decode_u8() -> int:
	if check_remaining_datagram_size(1):
		var read := _datagram.decode_u8(cursor)
		cursor += 1
		return read
	return 0

## Decodes and returns an unsigned int16 from the datagram buffer.
func decode_u16() -> int:
	if check_remaining_datagram_size(2):
		var read := _datagram.decode_u16(cursor)
		cursor += 2
		return read
	return 0

## Decodes and returns an unsigned int32 from the datagram buffer.
func decode_u32() -> int:
	if check_remaining_datagram_size(4):
		var read := _datagram.decode_u32(cursor)
		cursor += 4
		return read
	return 0

## Decodes and returns an unsigned int16 from the datagram buffer.
## If that value is [code]0xFFFF[/code], decodes and returns the next unsigned
## int32 from the datagram buffer instead.
func decode_count(decode_next_u32_if_max := false) -> int:
	var value := decode_u16()
	if value == 0xFFFF and decode_next_u32_if_max:
		return decode_u32()
	else:
		return value

## Decodes and returns a signed int32 from the datagram buffer.
func decode_s32() -> int:
	if check_remaining_datagram_size(4):
		var read := _datagram.decode_s32(cursor)
		cursor += 4
		return read
	return 0

## Decodes and returns a float from the datagram buffer.
func decode_float() -> float:
	if check_remaining_datagram_size(4):
		var read := _datagram.decode_float(cursor)
		cursor += 4
		return read
	return 0.0

## Decodes and returns a double from the datagram buffer.
func decode_double() -> float:
	if check_remaining_datagram_size(8):
		var read := _datagram.decode_double(cursor)
		cursor += 8
		return read
	return 0.0

## Decodes and returns a float (or double if [member BamParser.use_f64_stdfloats]
## is [code]true[/code]) from the datagram buffer.
func decode_stdfloat() -> float:
	if use_f64_stdfloats:
		return decode_double()
	else:
		return decode_float()

## Calls [param decode_function] twice to read two successive values from the
## datagram buffer, and returns the values in a [Vector2].
func decode_vector2(decode_function: Callable) -> Vector2:
	return Vector2(
		decode_function.call(),
		decode_function.call(),
	)

## Calls [param decode_function] three times to read three successive values
## from the datagram buffer, and returns the values in a [Vector3].
func decode_vector3(decode_function: Callable) -> Vector3:
	return Vector3(
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
	)

## Calls [param decode_function] four times to read four successive values
## from the datagram buffer, and returns the values in a [Vector4].
func decode_vector4(decode_function: Callable) -> Vector4:
	return Vector4(
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
	)

## Decodes 16 successive [code]stdfloat[/code] values from the datagram buffer,
## and returns the values as a [Projection] (matrix).
func decode_projection() -> Projection:
	return Projection(
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
	)

## Decodes four successive [code]stdfloat[/code] values from the datagram buffer,
## and returns the values as a [Color].
func decode_color() -> Color:
	return Color(
		decode_stdfloat(),
		decode_stdfloat(),
		decode_stdfloat(),
		decode_stdfloat(),
	)

## Decodes a DirectX style color value from a uint32 (AGBR)
func decode_color_dcba() -> Color:
	# These values work but they don't seem to match the documentation
	var vector: Vector4 = decode_vector4(decode_u8)
	return Color(vector.x / 255, vector.y / 255, vector.z / 255, vector.w / 255)

## Decodes a DirectX style color value from a uint32 (ARGB)
func decode_color_dabc() -> Color:
	# These values work but they don't seem to match the documentation
	var vector: Vector4 = decode_vector4(decode_u8)
	return Color(vector.z / 255, vector.y / 255, vector.x / 255, vector.w / 255)

## Decodes and returns a [String] from the datagram buffer.
func decode_string() -> String:
	var length := decode_u16()
	if check_remaining_datagram_size(length):
		var slice := _datagram.slice(cursor, cursor + length)
		cursor += length
		return slice.get_string_from_utf8()
	return String()

## Decodes the next value as a size for a datagram, and then returns a
## [PandaDatagramReader].
func decode_datagram() -> PandaDatagramReader:
	var datagram_info := get_next_datagram_info(_datagram, cursor)
	return get_script().new(
		take_size(datagram_info.size + datagram_info.size_value_length),
		0, _reader_args,
	)

## Slices and returns [param size] bytes from the datagram buffer.
func take_size(size: int) -> PackedByteArray:
	if check_remaining_datagram_size(size):
		var slice := _datagram.slice(cursor, cursor + size)
		cursor += size
		return slice
	return PackedByteArray()

## Slices and returns the remaining bytes from the datagram buffer.
func take_remaining() -> PackedByteArray:
	var slice := _datagram.slice(cursor, cursor + datagram_size_remaining)
	cursor += datagram_size_remaining
	return slice

## Returns the number of bytes in the datagram.
func size() -> int:
	return _datagram.size()
