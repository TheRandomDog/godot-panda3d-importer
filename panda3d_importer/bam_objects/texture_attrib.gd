extends PandaRenderAttrib
class_name PandaTextureAttrib
## A render attribute applied to objects that need to be textured.
##
## Contains information about the texture itself, along with what TextureStages
## it should belong to.

var off_all_stages: bool  # TODO: ?
var o_off_stages: Array[PandaTextureStage]
var o_on_stages: Array[PandaTextureStage]
var o_textures: Array[PandaTexture]
var implicit_sort: int
var override := 0
var sampler: SamplerState

func parse_object_data() -> void:
	super()
	
	off_all_stages = bam_parser.decode_bool()
	var off_stage_count := bam_parser.decode_u16()
	for i in range(off_stage_count):
		o_off_stages.append(bam_parser.decode_and_follow_pointer() as PandaTextureStage)
	
	var on_stage_count := bam_parser.decode_u16()
	var on_stage: PandaTextureStage
	for i in range(on_stage_count):
		on_stage = bam_parser.decode_and_follow_pointer() as PandaTextureStage
		o_textures.append(bam_parser.decode_and_follow_pointer() as PandaTexture)
		if bam_parser.version >= [6, 15]:
			implicit_sort = bam_parser.decode_u16()
		else:
			implicit_sort = i
		if bam_parser.version >= [6, 23]:
			override = bam_parser.decode_s32()
		
		o_on_stages.insert(implicit_sort, on_stage)
		implicit_sort += 1
		
		if bam_parser.version >= [6, 36]:
			var has_sampler := bam_parser.decode_bool()
			if has_sampler:
				sampler = SamplerState.new()
				sampler.parse_data(bam_parser)

func apply_to_surface(surface: Surface) -> void:
	super(surface)
	# TODO: Support stages
	if o_textures:
		var texture := o_textures[0]
		surface.add_texture(texture.load_texture())
		if texture.alpha_filename:
			surface.add_alpha()
