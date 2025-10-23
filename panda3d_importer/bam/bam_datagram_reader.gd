@tool
class_name PandaBAMDatagramReader
extends PandaDatagramReader

var bam_parser: WeakRef
var _use_u32_object_ids := false

func _init(
	packed_byte_array: PackedByteArray,
	byte_offset: int = 0,
	args: Array = [],
) -> void:
	bam_parser = weakref(args[0])
	super(packed_byte_array, byte_offset, args)
	push_errors = false

func get_parser() -> BamParser:
	return bam_parser.get_ref()

## Returns [code]true[/code] if there is enough buffer in the datagram to read
## [param length] bytes.
func check_remaining_datagram_size(length: int) -> bool:
	var result := super(length)
	if result == false:
		get_parser().parse_error(
			S_SIZE_CHECK_FAILED % [length, datagram_size_remaining],
			ERR_FILE_EOF
		)
	return result

func decode_object_code() -> int:
	if not get_parser().use_object_stream_codes:
		return BamParser.BamObjectCode.ADJUNCT
	return decode_u8()

## Decodes and returns a pointer to another [BamObject] from the datagram buffer.
func decode_pointer() -> int:
	if _use_u32_object_ids:
		return decode_u32()
	else:
		var result := decode_u16()
		if result == 0xFFFF:
			_use_u32_object_ids = true
		return result

## Decodes a pointer to another [BamObject] from the datagram buffer and
## attempts to resolve said BamObject before returning it.
func decode_and_follow_pointer(allow_null := false) -> BamObject:
	return get_parser().get_object(decode_pointer(), allow_null)


func _next_object(
	allow_null: bool,
	object_type_class: GDScript = null,
) -> WeakRef:
	var object := decode_and_follow_pointer(allow_null)
	if object_type_class:
		if (
			(object == null and not allow_null)
			or (not allow_null and not is_instance_of(object, object_type_class))
		):
			get_parser().parse_error(
				'Expected object to be of type %s, but received %s' %
				[object_type_class.get_global_name(), object]
			)
			return WeakRef.new()
	return weakref(object)

func next_object_ref(object_type_class: GDScript = null) -> WeakRef:
	return _next_object(false, object_type_class)

func next_object_ref_or_null(object_type_class: GDScript = null) -> WeakRef:
	return _next_object(true, object_type_class)

func next_object_ref_array(
	object_type_class: GDScript = null,
	decode_count_func := decode_count,
) -> Array[WeakRef]:
	return next_object_ref_array_and_extra(
		Callable(), object_type_class, decode_count_func
	)

func next_object_ref_array_and_extra(
	extra_callable: Callable,
	object_type_class: GDScript = null,
	decode_count_func := decode_count,
) -> Array[WeakRef]:
	var weakref_array: Array[WeakRef]
	var count: int = decode_count_func.call()
	for i in count:
		var object_ref := _next_object(false, object_type_class)
		if object_ref.get_ref():
			weakref_array.append(object_ref)
		if extra_callable.is_valid():
			extra_callable.call(i, object_ref)
	return weakref_array
