extends PandaRenderAttrib
class_name PandaTextureAttrib
## A render attribute applied to objects that need to be textured.
##
## Contains information about the texture itself, along with what TextureStages
## it should belong to.

var off_all_stages: bool  # TODO: ?

var _off_stages: Array[WeakRef]
func get_off_stages() -> Array[PandaTextureStage]:
	var array: Array[PandaTextureStage]
	array.assign(get_objects_from_array(_off_stages))
	return array

var _on_stages: Array[WeakRef]
func get_on_stages() -> Array[PandaTextureStage]:
	var array: Array[PandaTextureStage]
	array.assign(get_objects_from_array(_on_stages))
	return array

var _textures: Array[WeakRef]
func get_textures() -> Array[PandaTexture]:
	var array: Array[PandaTexture]
	array.assign(get_objects_from_array(_textures))
	return array

var sampler: SamplerState

var _next_implicit_sort: int
var _override: int = 0

func _decode_on_stage_texture(i: int, _stage: WeakRef) -> void:
	var implicit_sort := i
	_textures.append(datagram.next_object_ref(PandaTexture))
	if bam_parser.version >= [6, 15]:
		implicit_sort = datagram.decode_u16()
	if bam_parser.version >= [6, 23]:
		_override = datagram.decode_s32()

	_next_implicit_sort = max(_next_implicit_sort, implicit_sort + 1)
	_next_implicit_sort += 1

	if bam_parser.version >= [6, 36]:
		var has_sampler := datagram.decode_bool()
		if has_sampler:
			sampler = SamplerState.new(datagram)

func parse_object_data() -> void:
	super()

	off_all_stages = datagram.decode_bool()
	_off_stages = datagram.next_object_ref_array(PandaTextureStage)
	_on_stages = datagram.next_object_ref_array_and_extra(
		_decode_on_stage_texture, PandaTextureStage
	)

func apply_to_surface(surface: Surface) -> void:
	super(surface)
	# TODO: Support stages
	if _textures:
		var texture := get_textures()[0]
		surface.add_texture(texture.load_texture())
