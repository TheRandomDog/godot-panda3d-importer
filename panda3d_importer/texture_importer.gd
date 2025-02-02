@tool
extends EditorImportPlugin

var sgi_parser := SGIParser.new()

enum Presets { DEFAULT }

func _can_import_threaded():
	return false

func _get_importer_name():
	return "panda3d.texture"

func _get_visible_name():
	return "Texture2D (Panda3D)"

func _get_recognized_extensions():
	return ["jpg", "jpeg", "png"] + SGIImporter.EXTENSIONS

func _get_save_extension():
	return "tex"

func _get_resource_type():
	return "ImageTexture"

func _get_preset_count():
	return 1
	
func _get_priority() -> float:
	return 1.0
	
func _get_import_order() -> int:
	return 2

func _get_preset_name(preset_index):
	match preset_index:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(path, preset_index):
	var new_path = path.rsplit('.', true, 1)[0] + '_a.rgb'
	var alpha_filename = ''
	if FileAccess.file_exists(new_path):
		alpha_filename = new_path
	match preset_index:
		Presets.DEFAULT:
			return [
				{
				   "name": "alpha_filename",
				   "default_value": alpha_filename.replace('res://', ''),
				},
				{
				   "name": "alpha_file_channel",
				   "default_value": 0,
				},
			]
		_:
			return []

func _get_option_visibility(path, option_name, options):
	return true

func _import(source_file: String, save_path, options, platform_variants, gen_files) -> Error:
	var primary_file = Image.new()
	var error: Error
	match source_file.get_extension():
		'jpg', 'jpeg':
			error = primary_file.load_jpg_from_buffer(FileAccess.get_file_as_bytes(source_file))
		'png':
			error = primary_file.load_png_from_buffer(FileAccess.get_file_as_bytes(source_file))
		'rgb', 'rgba', 'sgi':
			error = sgi_parser.load(source_file)
			primary_file = sgi_parser.image
	if error != Error.OK:
		return error
	elif primary_file.is_empty():
		return ERR_FILE_CORRUPT
	
	var tex: ImageTexture
	if options['alpha_filename']:
		var alpha_image = load('res://' + options['alpha_filename'])
		if alpha_image.is_empty():
			return ERR_FILE_CORRUPT
		
		tex = Panda2Godot.merge_main_and_alpha_images(
			primary_file, alpha_image, options['alpha_file_channel']
		)
	else:
		tex = ImageTexture.create_from_image(primary_file)
	
	var import_filename = save_path + "." + _get_save_extension()
	return ResourceSaver.save(tex, import_filename, ResourceSaver.FLAG_COMPRESS)
