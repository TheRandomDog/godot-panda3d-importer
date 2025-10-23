@tool
extends EditorImportPlugin

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.bam.font"

func _get_visible_name():
	return "BAM Font"

func _get_recognized_extensions():
	return ["bam", "pz"]

func _get_save_extension() -> String:
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

func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	platform_variants: Array[String],
	gen_files: Array[String]
) -> Error:
	if not (source_file.ends_with('.bam') or source_file.ends_with('.bam.pz')):
		return ERR_SKIP

	var parser := BamParser.new()
	var error := parser.load(source_file)
	if error:
		return error
	assert(parser.objects.size() > 0)

	var font := parser.get_model_root().make_font(
		options['small_caps'],
		options['small_caps_scale'],
	)
	if parser.error:
		return parser.error

	var filename := save_path + "." + _get_save_extension()
	return ResourceSaver.save(font, filename)
