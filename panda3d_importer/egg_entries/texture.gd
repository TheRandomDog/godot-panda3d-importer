extends EggEntry
class_name EggTexture

var ref_name: String
var texture: Texture2D
var format: String
var transform: EggTransform2D

var alpha: Image
var alpha_file_channel := 0
var wrap_u := SamplerState.WrapMode.CLAMP
var wrap_v := SamplerState.WrapMode.CLAMP
var border_color: Color


func read_entry() -> void:
	ref_name = name()
	var path := contents()
	texture = _load_texture(contents())

func _load_texture(path: String) -> Texture2D:
	if path.get_extension() in SGIImporter.EXTENSIONS:
		return ImageTexture.create_from_image(load("res://" + path))
	else:
		return load("res://" + path)

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Transform':
			transform = EggTransform2D.new(egg_parser, child)

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		"alpha-file":
			alpha = load("res://" + data)
			texture = Panda2Godot.merge_main_and_alpha_images(
				texture.get_image(), alpha
			)
		"alpha-file-channel":
			alpha_file_channel = data.to_int()  # TODO: this needs to be passed to the above method
		"format":
			format = data
