extends PandaRenderEffect
class_name PandaCharacterJointEffect

var o_character: PandaCharacter

func parse_object_data() -> void:
	super()
	o_character = bam_parser.decode_and_follow_pointer() as PandaCharacter
