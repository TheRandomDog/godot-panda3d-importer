extends PandaVertexTransform
class_name PandaCharacterVertexSlider

var _character_slider: WeakRef
var character_slider: PandaCharacterSlider:
	get:
		return get_object(_character_slider)

func parse_object_data() -> void:
	super()
	_character_slider = datagram.next_object_ref(PandaCharacterSlider)
