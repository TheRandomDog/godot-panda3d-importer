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
	return "panda3d.egg.model"

func _get_visible_name():
	return "Egg Model"

func _get_recognized_extensions():
	return ["egg", "pz"]

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
	return []
	return [
		{
			"name": "is_character",
			"default_value": true,
		},
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
			"hint_string": "%d/%d:*.egg" % [TYPE_STRING, PROPERTY_HINT_FILE],
			
		}
	]

		
func _get_option_visibility(path, option_name, options):
	if option_name.begins_with('animations/'):
		return options['is_character']
	return true
	
func _import(source_file: String, save_path, options, platform_variants, gen_files) -> Error:
	if not (source_file.ends_with('.egg') or source_file.ends_with('.egg.pz')):
		return ERR_SKIP
	
	var parser := EggParser.new()
	var result := parser.load(source_file)
	if result != OK:
		print('result not OK, ', result)
		return result
	#assert(parser.objects.size() > 0)
	
	var scene = PackedScene.new()
	var model = parser.make_model()
	for child in model.find_children('*', "", true, false):
		child.set_owner(model)
	scene.pack(model)
	
	#parser.cleanup()

	var filename = save_path + "." + _get_save_extension()
	var x = ResourceSaver.save(scene, filename)
	print(filename, x)
	return x
