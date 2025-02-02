@tool
extends EditorImportPlugin

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.bam.sprite"

func _get_visible_name():
	return "BAM Model as Sprite2Ds"

func _get_recognized_extensions():
	return ["bam", "pz"]

func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return 1
	
func _get_priority():
	return 0.1

func _get_import_order():
	return 1

func _get_preset_name(preset_index):
	return 'Default'

func _get_import_options(path, preset_index):
	return [
		{
			'name': 'scale',
			'default_value': Vector2(1, 1),
			'property_hint': PROPERTY_HINT_LINK,
		}
	]
		
func _get_option_visibility(path, option_name, options):
	return true
	
func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	if not (source_file.ends_with('.bam') or source_file.ends_with('.bam.pz')):
		return ERR_SKIP
	
	var parser := BamParser.new()
	parser.configuration['parser']['make_sprite_scale'] = options['scale']
	
	var error := parser.load(source_file)
	if error:
		return error
	for object in parser.objects.values():
		if object.object_type.name == 'Texture':
			var new_path = parser.get_dependency_path(
				object.filename.rsplit('.', true, 1)[0] + '_a.rgb'
			)
			var tex_options = {}
			if FileAccess.file_exists('res://' + new_path):
				error = append_import_external_resource(
					'res://' + new_path, {},
					'panda3d.rgb'
				)
				tex_options['alpha_filename'] = new_path
			if error:
				return error
			error = append_import_external_resource(
				'res://' + parser.get_dependency_path(object.filename),
				tex_options,
				"panda3d.texture"
			)
			if error:
				return error
	assert(parser.objects.size() > 0)
	
	var scene = PackedScene.new()
	var sprite_holder := parser.make_sprites()
	if parser.error:
		return parser.error
	for child in sprite_holder.find_children('*', "", true, false):
		child.set_owner(sprite_holder)
	scene.pack(sprite_holder)
	parser.cleanup()

	var filename = save_path + "." + _get_save_extension()
	return ResourceSaver.save(scene, filename)
