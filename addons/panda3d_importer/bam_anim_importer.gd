@tool
extends EditorImportPlugin

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.bam.anim"

func _get_visible_name():
	return "BAM Animation"

func _get_recognized_extensions():
	return ["bam", "pz"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Animation"

func _get_preset_count():
	return 1
	
func _get_priority():
	return 0.5

func _get_import_order():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return []#[{"name": "my_option", "default_value": false}]
	
func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	var parser := BamParser.new()
	var result := parser.load(source_file)
	if result != OK:
		print('result not OK, ', result)
		return result
	assert(parser.objects.size() > 0)
	
	var animation = parser.make_animation()
	
	var filename = save_path + "." + _get_save_extension()
	var x = ResourceSaver.save(animation, filename)
	print(filename, x)
	return x
