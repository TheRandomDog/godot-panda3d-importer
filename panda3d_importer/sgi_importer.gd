@tool
extends EditorImportPlugin
class_name SGIImporter

const EXTENSIONS := ["sgi", "rgb", "rgba", "bw"]

var parser = SGIParser.new()

func _get_importer_name():
	return "panda3d.rgb"

func _get_visible_name():
	return "SGI/RGB File"

func _get_recognized_extensions():
	return EXTENSIONS

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Image"

func _get_preset_count():
	return 1
	
func _get_priority():
	return 1.5

func _get_import_order():
	return 0

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return []

func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	var error = parser.parse_sgi_image(source_file)
	if error != Error.OK:
		return error

	var filename = save_path + "." + _get_save_extension()
	return ResourceSaver.save(parser.image, filename)
