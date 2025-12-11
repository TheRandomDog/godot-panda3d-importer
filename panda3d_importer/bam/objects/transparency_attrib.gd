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
	mode = datagram.decode_u8() as Mode

func apply_to_material(material: PandaMaterial3D) -> void:
	super(material)
	if mode > Mode.NONE:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if mode == Mode.PREMULTIPLIED_ALPHA:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
