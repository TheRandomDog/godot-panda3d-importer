extends EggEntry
class_name EggPolygon

var vertex_ref: EggVertexRef
var texture_ref: String
var texture: EggTexture
var normal: Vector3
var color := Color.WHITE
var backface: bool

var bin: String
var draw_order: int = 0
var visible: bool = true

func read_child(child: Dictionary) -> void:
	match child['type']:
		'TRef':
			texture_ref = child['contents']
		'Texture':
			texture = EggTexture.new(egg_parser, child)
		'Normal':
			normal = EggEntry.as_vector3(child)
		'RGBA':
			color = EggEntry.as_color(child)
		'BFace':
			backface = EggEntry.as_bool(child)
		'VertexRef':
			vertex_ref = EggVertexRef.new(egg_parser, child)

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		'bin':
			bin = data
		'draw_order':
			draw_order = data.to_int()
		'visibility':
			assert(data == 'hidden' or data == 'normal')
			visible = data == 'normal'

func get_texture() -> EggTexture:
	if texture_ref:
		return egg_parser.textures[texture_ref]
	else:
		return texture

func get_uv_transform() -> Transform2D:
	var texture := get_texture()
	if texture.transform:
		return texture.transform.transform
	else:
		return Transform2D()
