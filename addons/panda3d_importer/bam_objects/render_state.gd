extends BamObject
class_name PandaRenderState
## A required child object of PandaNode that describes how it's rendered. 
##
## PandaRenderAttribs are only applied in Panda3D when they encounter a GeomNode
## child (containing geometry).

var o_attribs: Array[PandaRenderAttrib]
var attrib_overrides: Array[int]

func parse_object_data() -> void:
	var attrib_count = bam_parser.decode_u16()
	for i in range(attrib_count):
		o_attribs.append(
			bam_parser.decode_and_follow_pointer() as PandaRenderAttrib
		)
		attrib_overrides.append(bam_parser.decode_s32())
