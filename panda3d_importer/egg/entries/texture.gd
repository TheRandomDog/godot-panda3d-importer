extends EggEntry
class_name EggTexture

var ref_name: String
var texture := PandaImageAndAlphaTexture.new()
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
	texture.image = _load_image(contents())

func _load_image(path: String) -> Image:
	var resource: Resource = load("res://" + path)
	if resource is Texture2D:
		return resource.get_image()
	elif resource is Image:
		return resource
	else:
		return null

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Transform':
			transform = EggTransform2D.new(egg_parser, child)

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		"alpha-file":
			texture.alpha_image = _load_image(data)
		"alpha-file-channel":
			texture.alpha_channel = data.to_int()
		"format":
			format = data
