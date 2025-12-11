@tool
extends EditorSceneFormatImporter

const _HIDDEN_IMPORT_OPTION_CONSTANTS = {
	'nodes/import_as_skeleton_bones': false,
	'nodes/use_name_suffixes': false,
	'nodes/use_node_type_suffixes': false,

	'animation/import': false,
	'animation/fps': 30.0,
}

const _VISIBLE_IMPORT_OPTION_DEFAULTS = {
	'meshes/generate_lods': false,
	'meshes/create_shadow_meshes': false,
	'meshes/light_baking': GeometryInstance3D.GI_MODE_DISABLED,
}

enum Presets {
	NO_ANIMATIONS,
	ANIMATION_MANUAL,
	ANIMATION_WILDCARD,
}

func _get_extensions() -> PackedStringArray:
	return ["bam", "pz"]

#func _get_import_options(path: String) -> void:
#	if path.get_extension() not in _get_extensions():
#		return
#
#	#for option in _HIDDEN_IMPORT_OPTION_CONSTANTS:
#	#	add_import_option(option, _HIDDEN_IMPORT_OPTION_CONSTANTS[option])
#	#for option in _VISIBLE_IMPORT_OPTION_DEFAULTS:
#	#	add_import_option(option, _VISIBLE_IMPORT_OPTION_DEFAULTS[option])
#
#	add_import_option_advanced(
#		TYPE_PACKED_STRING_ARRAY,
#		'animation/animations',
#		[],
#		PROPERTY_HINT_TYPE_STRING,
#		'%d/%d:*.bam' % [TYPE_STRING, PROPERTY_HINT_FILE],
#	)

func _get_import_options(path: String) -> void:
	#add_import_option('nodes/convert_to_2d')
	add_import_option(
		'meshes/rotation_matrix',
		Transform3D(
			Basis().rotated(Vector3(-1, 0, 0), -PI / 2),
			Vector3()
		),
	)
	add_import_option('meshes/pixel_size', 0.01)
	add_import_option_advanced(
		TYPE_INT,
		'character/if_excess_transform_blends',
		BAMParserConfigs.BAMExcessTransformBlendBehavior.ERROR,
		PROPERTY_HINT_ENUM,
		','.join(BAMParserConfigs.BAMExcessTransformBlendBehavior.keys().map(
			func(enum_key: String) -> String: return enum_key.capitalize()
		))
	)

	if not path:
		return

	add_import_option_advanced(
		TYPE_DICTIONARY,
		'animation/animations',
		{},
		PROPERTY_HINT_DICTIONARY_TYPE,
		"StringName;%d/%d:*.bam,*.bam.pz" % [TYPE_STRING, PROPERTY_HINT_FILE],
	)

func _get_option_visibility(path: String, for_animation: bool, option: String) -> Variant:
	if option == 'animation/animations':
		return not for_animation
	return null

#func _get_option_visibility(path: String, for_animation: bool, option: String) -> Variant:
#	#prints(option in _HIDDEN_IMPORT_OPTION_CONSTANTS, path, for_animation, option)
	#if option in _HIDDEN_IMPORT_OPTION_CONSTANTS or option in _VISIBLE_IMPORT_OPTION_DEFAULTS:
	#	return false
	#return true
#	return true

func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	#prints(path, flags, options)
	if not (path.ends_with('.bam') or path.ends_with('.bam.pz')):
		return null

	#print(options)
	#for option in _VISIBLE_IMPORT_OPTION_DEFAULTS:
	#	options[option] = _VISIBLE_IMPORT_OPTION_DEFAULTS[option]
	#print(options)

	var parser := BamParser.new()
	parser.configurations[BAMParserConfigs.GLOBAL].import_flags = flags
	parser.configurations[PandaTransformBlendTable].excess_transform_blend_behavior = \
		options['character/if_excess_transform_blends']
	var error := parser.load(path)
	if error:
		return null
	assert(parser.objects.size() > 0)

	#for dependency in parser.import_dependency_manager.dependencies:
	#	error = append_import_external_resource('res://' + dependency.path)
	#	if error:
	#		return null

	#var scene := PackedScene.new()
	var scene: Node
	var model_root := parser.get_model_root()
	if flags & IMPORT_DISCARD_MESHES_AND_MATERIALS:
		var animation_library := model_root.make_animation_library()
		if parser.error:
			return null#parser.error

		var animation_player := AnimationPlayer.new()
		animation_player.add_animation_library(&'', animation_library)
		scene = Node.new()
		scene.add_child(animation_player)
	else:
		var external_animations: Array[AnimationLibrary]
		var external_animation_paths: Dictionary[StringName, String]
		external_animation_paths.assign(options.get(&'animation/animations', {}))
		for animation_name in external_animation_paths:
			var animation_path := external_animation_paths[animation_name]
			var resource := ResourceLoader.load(animation_path, 'AnimationLibrary')
			if resource is not AnimationLibrary:
				push_warning('Skipping invalid animation: %s' % animation_path)
				continue

			resource.resource_name = animation_name
			external_animations.append(resource)

		scene = model_root.make_scene_tree(external_animations)
		if parser.error:
			return null#parser.error

	for child in scene.find_children('*', "", true, false):
		child.set_owner(scene)
	#scene.pack(model)

	#var filename := save_path + "." + _get_save_extension()
	return scene#ResourceSaver.save(scene, filename)
