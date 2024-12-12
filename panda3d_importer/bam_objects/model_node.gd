extends PandaNode
class_name PandaModelNode
## A BAM Object that represents the parent / root of a heirarchy of objects
## considered to be one re-usable unit.
##
## Despite the Panda3D documentation suggesting that this node doesn't affect
## rendering, this object does have properties that suggest otherwise.

enum PreserveTransform { NONE, LOCAL, NET, DROP_NODE, NO_TOUCH }
enum SceneGraphReducerAttribTypes { 
	TRANSFORM = 1,
	COLOR = 2,
	COLOR_SCALE = 4,
	TEX_MATRIX = 8,
	CLIP_PLANE = 16,
	CULL_FACE = 32,
	APPLY_TEXTURE_COLOR = 64,
	OTHER = 128
}

var preserve_transform: PreserveTransform
var preserve_attributes: int

func parse_object_data() -> void:
	super()
	preserve_transform = bam_parser.decode_u8() as PreserveTransform
	preserve_attributes = bam_parser.decode_u16()
