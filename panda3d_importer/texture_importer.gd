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
	#prints(new_path, FileAccess.file_exists(new_path))
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

func _import(source_file, save_path, options, platform_variants, gen_files) -> Error:
	var path = source_file.rsplit('.', true, 1)
	var file_extension = path[1]
	
	#var primary_file = Image.create_from_data(128, 128, false, Image.FORMAT_RGB8, primary_file_buffer)
	var primary_file = Image.new()
	var error: Error
	match file_extension:
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
	
	if options['alpha_filename']:
		var alpha_image = load('res://' + options['alpha_filename'])
		if alpha_image.is_empty():
			return ERR_FILE_CORRUPT
		
		primary_file.convert(Image.FORMAT_RGBA8)
		var primary_file_size := primary_file.get_size()
		if primary_file_size != alpha_image.get_size():
			alpha_image.resize(
				primary_file_size.x, primary_file_size.y,
				Image.INTERPOLATE_CUBIC
			)
		
		var color: Color
		for y in range(primary_file.get_height()):
			for x in range(primary_file.get_width()):
				color = primary_file.get_pixel(x, y)
				color.a = alpha_image.get_pixel(x, y)[options['alpha_file_channel']]
				primary_file.set_pixel(x, y, color)
	
	#primary_file.compress(Image.COMPRESS_BPTC)
	var tex = ImageTexture.create_from_image(primary_file)
	
	var import_filename = save_path + "." + _get_save_extension()
	var x = ResourceSaver.save(tex, import_filename, ResourceSaver.FLAG_COMPRESS)
	return OK
