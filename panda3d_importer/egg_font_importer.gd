@tool
extends EditorImportPlugin

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.egg.font"

func _get_visible_name():
	return "Egg Font"

func _get_recognized_extensions():
	return ["egg", "pz"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "FontFile"

func _get_preset_count():
	return 1
	
func _get_priority():
	return 0.4

func _get_import_order():
	return 1

func _get_preset_name(preset_index):
	return 'Default'

func _get_import_options(path, preset_index):
	return [
		{
			"name": "small_caps",
			"default_value": false,
		},
		{
			"name": "small_caps_scale",
			"default_value": 0.8,
		},
	]
		
func _get_option_visibility(path, option_name, options):
	return true
	
func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	if not (source_file.ends_with('.egg') or source_file.ends_with('.egg.pz')):
		return ERR_SKIP
	
	var parser := EggParser.new()
	var result := parser.load(source_file)
	if result != OK:
		print('result not OK, ', result)
		return result
	
	var font := parser.make_font(options['small_caps'], options['small_caps_scale'])
	if parser.error:
		print('result not OK, ', parser.error)
		return parser.error
	
	var filename = save_path + "." + _get_save_extension()
	var x = ResourceSaver.save(font, filename)
	print(filename, x)
	return x
