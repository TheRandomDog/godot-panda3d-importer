extends BamObject
class_name PandaTextureStage
## Contains data about a stage in Panda3D's multi-texture pipeline.
##
## Typically, most textures will belong to one "default" TextureStage, but
## more can be added for more complex render scenarios.
# TODO: Stages aren't really supported yet

enum CombineMode {
	UNDEFINED,
	REPLACE,
	MODULATE,
	ADD,
	ADD_SIGNED,
	INTERPOLATE,
	SUBTRACT,
	DOT3_RGB,
	DOT3_RGBA,
}
enum CombineOperand {
	UNDEFINED,
	SRC_COLOR,
	ONE_MINUS_SRC_COLOR,
	SRC_ALPHA,
	ONE_MINUS_SRC_ALPHA,
}
enum CombineSource {
	UNDEFINED,
	TEXTURE,
	CONSTANT,
	PRIMARY_COLOR,
	PREVIOUS,
	CONSTANT_COLOR_SCALE,
	LAST_SAVED_RESULT,
}
enum Mode {
	MODULATE,
	DECAL,
	BLEND,
	REPLACE,
	ADD,
	COMBINE,
	BLEND_COLOR_SCALE,
	MODULATE_GLOW,
	MODULATE_GLOSS,
	NORMAL,
	NORMAL_HEIGHT,
	GLOW,
	GLOSS,
	HEIGHT,
	SELECTOR,
	NORMAL_GLOSS,
	EMISSION,
}

static var default_texcoord_name: PandaInternalName

static func _static_init() -> void:
	default_texcoord_name = BamObject.new_placeholder(PandaInternalName)
	default_texcoord_name.name = "texcoord"
	default_texcoord_name.resolved = true

# These are the values for a default TextureStage. For optimization, if default
# is `true`, the object has no further data and falls back on these values.
var name := "default"
var sort := 0
var priority := 0

var _texcoord_name: WeakRef
var texcoord_name: PandaInternalName:
	get:
		return get_object(_texcoord_name)

var mode := Mode.MODULATE
var color := Color()
var rgb_scale := 1
var alpha_scale := 1
var saved_result := false
var tex_view_offset := 0  # 6.26+
var rgb_combine_mode := CombineMode.UNDEFINED
var rgb_combinations: Array[Combination]
var alpha_combine_mode := CombineMode.UNDEFINED
var alpha_combinations: Array[Combination]

func parse_combinations() -> Array[Combination]:
	# TextureStage always has three combination entries, even if they're not used.
	# We don't need to store it like that, so we'll just call the right number
	# of decodes and toss the rest of the values.
	var combinations: Array[Combination]
	var combination_count := datagram.decode_u8()
	for i in range(combination_count):
		var combination := Combination.new()
		combination.source = datagram.decode_u8()
		combination.operand = datagram.decode_u8()
	for i in range(3 - combination_count):
		datagram.decode_u8()  # Combination Source
		datagram.decode_u8()  # Combination Operand
	return combinations

func parse_object_data() -> void:
	var default := datagram.decode_bool()
	if default:
		_texcoord_name = weakref(default_texcoord_name)
		return

	name = datagram.decode_string()
	sort = datagram.decode_s32()
	priority = datagram.decode_s32()

	_texcoord_name = datagram.next_object_ref(PandaInternalName)

	mode = datagram.decode_u8() as Mode
	color = datagram.decode_color()

	rgb_scale = datagram.decode_u8()
	alpha_scale = datagram.decode_u8()
	saved_result = datagram.decode_bool()
	if bam_parser.version >= [6, 26]:
		tex_view_offset = datagram.decode_u8()

	rgb_combine_mode = datagram.decode_u8() as CombineMode
	rgb_combinations = parse_combinations()

	alpha_combine_mode = datagram.decode_u8() as CombineMode
	alpha_combinations = parse_combinations()


class Combination:
	var source: CombineSource
	var operand: CombineOperand
