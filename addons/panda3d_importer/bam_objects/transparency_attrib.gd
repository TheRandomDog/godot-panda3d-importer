extends PandaRenderAttrib
class_name PandaTransparencyAttrib

enum Mode { 
	NONE,
	ALPHA,
	PREMULTIPLIED_ALPHA,
	MULTISAMPLE,
	MULTISAMPLE_MASK,
	BINARY,
	DUAL,
}

var mode: Mode

func parse_object_data() -> void:
	super()
	mode = bam_parser.decode_u8() as Mode

func apply_to_surface(surface: Surface) -> void:
	super(surface)
	# TODO
