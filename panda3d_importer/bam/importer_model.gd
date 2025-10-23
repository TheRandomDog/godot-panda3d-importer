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

func _get_save_extension() -> String:
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
	parser.configurations[PandaTransformBlendTable].excess_transform_blend_behavior = \
		options['character/if_excess_transform_blends']
	var error := parser.load(source_file)
	if error:
		return error
	assert(parser.objects.size() > 0)

	for dependency in parser.import_dependency_manager.dependencies:
		error = append_import_external_resource('res://' + dependency.path)
		if error:
			return error

	var scene := PackedScene.new()
	var model := parser.get_model_root().make_scene_tree()
	if parser.error:
		return parser.error
	for child in model.find_children('*', "", true, false):
		child.set_owner(model)
	scene.pack(model)

	var filename := save_path + "." + _get_save_extension()
	return ResourceSaver.save(scene, filename)
