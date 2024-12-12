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

class Combination:
	var source: CombineSource
	var operand: CombineOperand

# These are the values for a default TextureStage. For optimization, if default
# is `true`, the object has no further data and falls back on these values.
var name := "default"
var sort := 0
var priority := 0
var o_texcoord_name: PandaInternalName
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
	var combination_count := bam_parser.decode_u8()
	for i in range(combination_count):
		var combination := Combination.new()
		combination.source = bam_parser.decode_u8()
		combination.operand = bam_parser.decode_u8()
	for i in range(3 - combination_count):
		bam_parser.decode_u8()  # Combination Source
		bam_parser.decode_u8()  # Combination Operand
	return combinations

func parse_object_data() -> void:
	var default := bam_parser.decode_bool()
	if default:
		o_texcoord_name = BamObject.new_placeholder(PandaInternalName)
		o_texcoord_name.name = "texcoord"
		o_texcoord_name.resolved = true
		return
	
	name = bam_parser.decode_string()
	sort = bam_parser.decode_s32()
	priority = bam_parser.decode_s32()
	
	o_texcoord_name = bam_parser.decode_and_follow_pointer() as PandaInternalName
	
	mode = bam_parser.decode_u8() as Mode
	color = bam_parser.decode_color()
	
	rgb_scale = bam_parser.decode_u8()
	alpha_scale = bam_parser.decode_u8()
	saved_result = bam_parser.decode_bool()
	if bam_parser.version >= [6, 26]:
		tex_view_offset = bam_parser.decode_u8()
	
	rgb_combine_mode = bam_parser.decode_u8() as CombineMode
	rgb_combinations = parse_combinations()
		
	alpha_combine_mode = bam_parser.decode_u8() as CombineMode
	alpha_combinations = parse_combinations()
	
func involves_color_scale() -> bool:
	var source_is_constant_color_scale := func(c: Combination):
		return c.source == CombineSource.CONSTANT_COLOR_SCALE
		
	return (
		mode == Mode.BLEND_COLOR_SCALE or
		(mode == Mode.COMBINE and (
			rgb_combinations.any(source_is_constant_color_scale) or
			alpha_combinations.any(source_is_constant_color_scale)
		))
	)

func uses_color() -> bool:
	var source_is_constant := func(c: Combination): 
		return c.source == CombineSource.CONSTANT
		
	return (
		(mode == Mode.BLEND_COLOR_SCALE or mode == Mode.BLEND) or 
		(mode == Mode.COMBINE and (
			rgb_combinations.any(source_is_constant) or
			alpha_combinations.any(source_is_constant)
		))
	)

func uses_primary_color() -> bool:
	var source_is_primary_color := func(c: Combination): 
		return c.source == CombineSource.PRIMARY_COLOR
		
	return (
		mode == Mode.COMBINE and (
			rgb_combinations.any(source_is_primary_color) or
			alpha_combinations.any(source_is_primary_color)
		)
	)
	
func uses_last_saved_result() -> bool:
	var source_is_last_saved_result := func(c: Combination): 
		return c.source == CombineSource.LAST_SAVED_RESULT
		
	return (
		mode == Mode.COMBINE and (
			rgb_combinations.any(source_is_last_saved_result) or
			alpha_combinations.any(source_is_last_saved_result)
		)
	)
