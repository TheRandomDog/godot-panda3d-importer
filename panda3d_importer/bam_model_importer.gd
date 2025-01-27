@tool
extends EditorImportPlugin

enum Presets {
	NO_ANIMATIONS,
	ANIMATION_MANUAL,
	ANIMATION_WILDCARD,
}

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.bam.model"

func _get_visible_name():
	return "BAM Model"

func _get_recognized_extensions():
	return ["bam", "pz"]

func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return 1
	
func _get_priority():
	return 1.0

func _get_import_order():
	return 1

func _get_preset_name(preset_index):
	return 'Default'

func _get_import_options(path, preset_index):
	return [
		# Character
		{
			"name": "character/if_excess_transform_blends",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Error,Warn and remove least significant blend(s),Remove lease significant blend(s)"
		}
	]
	# TODO:
	[
		# Animations
		{
			"name": "animations/filename_wildcard",
			"default_value": "",
		},
		{
			"name": "animations/search_all_resource_directories",
			"default_value": false,
		},
		{
			"name": "animations/additional_animations",
			"default_value": [],
			#"property_hint": PROPERTY_HINT_FILE,
			"property_hint": PROPERTY_HINT_TYPE_STRING,
			#"hint_string": "%d/%d:1,10,1" % [TYPE_INT, PROPERTY_HINT_RANGE],
			"hint_string": "%d/%d:*.bam" % [TYPE_STRING, PROPERTY_HINT_FILE],
			
		}
	]
		
func _get_option_visibility(path, option_name, options):
	return true
	
func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	if not (source_file.ends_with('.bam') or source_file.ends_with('.bam.pz')):
		return ERR_SKIP
	
	var parser := BamParser.new()
	parser.configuration[PandaTransformBlendTable]['excess_transform_blend_behavior'] = (
		options['character/if_excess_transform_blends']
	)
	
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
	var model = parser.make_model()
	if parser.error:
		return parser.error
	for child in model.find_children('*', "", true, false):
		child.set_owner(model)
	scene.pack(model)
	parser.cleanup()

	var filename = save_path + "." + _get_save_extension()
	return ResourceSaver.save(scene, filename)
