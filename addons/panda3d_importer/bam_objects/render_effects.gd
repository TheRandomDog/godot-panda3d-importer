extends BamObject
class_name PandaRenderEffects
## A required child object of PandaNode that describes how it's rendered. 
##
## PandaRenderEffects are not limited to geometry and will be applied to any
## PandaNode.

var o_effects: Array[PandaRenderEffect]

func parse_object_data() -> void:
	var effects_count = bam_parser.decode_u16()
	for i in range(effects_count):
		o_effects.append(
			bam_parser.decode_and_follow_pointer() as PandaRenderEffect
		)
