class_name PandaTransformBlend
extends BAMStruct
## A data class containing weight data for transform blends (typically for joints/bones).

var entries: Array[TransformEntry]

func _init(datagram: PandaBAMDatagramReader) -> void:
	entries.assign(BAMStruct.make_array(TransformEntry, datagram))
	entries.sort_custom(
		func(a: TransformEntry, b: TransformEntry) -> bool:
			return a.weight < b.weight
	)


class TransformEntry extends BAMStruct:
	var _transform: WeakRef
	var transform: PandaVertexTransform:
		get:
			return get_object(_transform)

	var weight: float

	func _init(datagram: PandaBAMDatagramReader) -> void:
		_transform = datagram.next_object_ref(PandaVertexTransform)
		weight = datagram.decode_stdfloat()
