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

func _get_save_extension() -> String:
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

func _get_import_options(path: String, preset_index: int):
	var path_base := path.get_file().get_basename().to_lower()
	return [
		{
			'name': 'loop_mode',
			'default_value': (
				Animation.LoopMode.LOOP_LINEAR
				if path_base.ends_with('loop') or path_base.ends_with('cycle') else
				Animation.LoopMode.LOOP_NONE
			),
			'property_hint': PROPERTY_HINT_ENUM,
			'hint_string': 'None,Loop,Ping-Pong'
		}
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
	var parser := BamParser.new()
	parser.configurations[PandaAnimBundleNode].loop_mode = options['loop_mode']

	var error := parser.load(source_file)
	if error:
		return error
	assert(parser.objects.size() > 0)

	var animation := parser.get_model_root().get_animations().get(0)
	var filename := save_path + "." + _get_save_extension()
	return ResourceSaver.save(animation, filename)
