@tool
extends ImageTexture
class_name PandaImageAndAlphaTexture

@export var image: Image:
	set(new):
		if new:
			image = _update_image(new)
			set_image(image)
			if use_alpha:
				_update_alpha()
		else:
			image = new
			set_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
@export var alpha_image: Image:
	set(new):
		if alpha_image != new:
			alpha_image = new
			_update_alpha()
@export var alpha_channel := 0:
	set(new):
		if alpha_channel != new:
			alpha_channel = new
			_update_alpha()
@export var use_alpha := true:
	set(new):
		if use_alpha != new:
			use_alpha = new
			_update_alpha()

func _to_string() -> String:
	return '<ImageAndAlphaTexture image=%s alpha=%s>' % [image, alpha_image]

func _update_image(new: Image) -> Image:
	var new_image := Image.new()
	new_image.copy_from(new)
	new_image.convert(Image.FORMAT_RGBA8)
	return new_image

func _update_alpha() -> void:
	if not image or not alpha_image:
		return
	elif not use_alpha:
		set_image(image)
		return

	var image_data: PackedByteArray = image.data['data']
	var alpha_data: PackedByteArray = alpha_image.data['data']
	var image_index := 3
	for alpha_index in range(alpha_channel, alpha_data.size(), _get_alpha_num_of_channels()):
		image_data[image_index] = alpha_data[alpha_index]
		image_index += 4
	set_image(Image.create_from_data(
		image.get_width(),
		image.get_height(),
		image.has_mipmaps(),
		Image.FORMAT_RGBA8,
		image_data
	))

func _get_alpha_num_of_channels() -> int:
	match alpha_image.get_format():
		Image.FORMAT_L8, Image.FORMAT_R8:
			return 1
		Image.FORMAT_LA8, Image.FORMAT_RG8:
			return 2
		Image.FORMAT_RGB8:
			return 3
		Image.FORMAT_RGBA8:
			return 4
	assert(false)
	return 0
