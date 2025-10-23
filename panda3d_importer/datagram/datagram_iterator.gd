@tool
class_name PandaDatagramIterator
extends RefCounted
## A utility class to manage reading [PackedByteArray]s.
##
## This class is mostly a wrapper around built-in [PackedByteArray]
## functionality, but will push warnings/errors if something goes wrong.

var _datagrams: Array[PandaDatagramReader]
var _datagram_index: int = 0
var truncated := false
#var _datagram_reader_class: GDScript

func _init(
	packed_byte_array: PackedByteArray,
	byte_offset: int = 0,
	datagram_reader_class: GDScript = PandaDatagramReader,
	reader_args: Array = [],
) -> void:
	while byte_offset < packed_byte_array.size():
		_datagrams.append(datagram_reader_class.new(
			packed_byte_array, byte_offset, reader_args
		))
		byte_offset += _datagrams[-1]._datagram_size_with_length
		if _datagrams[-1].truncated:
			truncated = true

func _iter_init(_iter: Array) -> bool:
	return _datagram_index < _datagrams.size()

func _iter_next(_iter: Array) -> bool:
	_datagram_index += 1
	return _datagram_index < _datagrams.size()

func _iter_get(_iter: Variant) -> Variant:
	return _datagrams[_datagram_index]

func take_datagrams(count: int) -> Array[PandaDatagramReader]:
	var datagrams: Array[PandaDatagramReader]
	_datagram_index += count
	datagrams.assign(_datagrams.slice(_datagram_index - count, _datagram_index))
	return datagrams

func take_next_datagram() -> PandaDatagramReader:
	return take_datagrams(1).front()
