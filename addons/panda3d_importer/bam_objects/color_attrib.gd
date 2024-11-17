extends PandaRenderAttrib
class_name PandaColorAttrib
## A render attribute applied to objects that need to be colored.
##
## This coloring can include an indicator to use vertex or no coloring,
## or just to be colored a specific flat color.

enum Type { VERTEX, FLAT, OFF }
const SIFTER := Vector4(0.5, 0.5, 0.5, 0.5)

## The type of color to apply to an object.
var type: Type
## What color to apply if we're applying a [enum PandaColorAttrib.Type][code]FLAT[/code] color.
var color: Color

func parse_object_data() -> void:
	super()
	type = bam_parser.decode_u8() as Type
	# Panda3D quantizes flat colors to the nearest multiple of 1024, to prevent
	# runaway accumulation of slightly-different ColorAttribs. This is useful
	# to us anyhow to prevent the same problem with Surface Materials.
	if type == Type.FLAT:
		# Get our color as a vector, as it's easier to perform operations on.
		var color_vec := bam_parser.decode_vector4(bam_parser.decode_stdfloat)
		color_vec = ((color_vec * 1024) + SIFTER).floor() / 1024
		color = Color(color_vec.x, color_vec.y, color_vec.z, color_vec.w)
	else:
		color = bam_parser.decode_color()

func apply_to_surface(surface: Surface) -> void:
	super(surface)
	if type == Type.VERTEX:
		surface.add_vertex_coloring()
	elif type == Type.FLAT:
		surface.add_albedo_color(color)
	else:
		surface.add_albedo_color(Color.WHITE)
