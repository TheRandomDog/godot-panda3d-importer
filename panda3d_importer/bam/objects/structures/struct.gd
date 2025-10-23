class_name BAMStruct
extends RefCounted

func _init(datagram: PandaBAMDatagramReader) -> void:
	pass

static func make_array(
	struct_script: GDScript,
	datagram: PandaBAMDatagramReader,
	decode_count_func := Callable()
) -> Array:
	return make_array_and_extra(Callable(), struct_script, datagram, decode_count_func)

static func make_array_and_extra(
	extra_callable: Callable,
	struct_script: GDScript,
	datagram: PandaBAMDatagramReader,
	decode_count_func := Callable()
) -> Array:
	var array: Array
	var count: int
	if decode_count_func.is_valid():
		count = decode_count_func.call()
	else:
		count = datagram.decode_count()
	array.resize(count)
	for i in count:
		array[i] = struct_script.new(datagram)
		if extra_callable.is_valid():
			extra_callable.call(i, array[i])
	return array

func get_object(weakref: WeakRef) -> BamObject:
	return weakref.get_ref() if weakref else null

func get_objects_from_array(weakref_array: Array[WeakRef]) -> Array:
	return weakref_array.filter(
		func(weakref: WeakRef) -> BamObject: return weakref.get_ref()
	)
