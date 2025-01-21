extends Object
class_name Panda2Godot

static var ROTION_MATRIX = Transform3D(
	Basis().rotated(Vector3(-1, 0, 0), -PI / 2),
	Vector3()
)

static func fix_position(pos: Vector3) -> Vector3:
	return Vector3(pos.x, pos.z, -pos.y)

## Returns a suitable Basis object given a Panda3D HPR rotation value.
static func get_basis_from_hpr(hpr: Vector3, rotated:=false) -> Basis:
	# For euler angles, Panda3D supplies: Vector3(H, P, R)
	#					Godot expects:    Vector3(P, H, R)
	# Then, Panda3D applies rotation in roll-pitch-yaw order.
	hpr = Vector3(deg_to_rad(hpr.y), deg_to_rad(hpr.x), -deg_to_rad(hpr.z))
	var basis = Basis.from_euler(hpr, EULER_ORDER_YXZ)
	if rotated:
		return basis.rotated(Vector3.LEFT, -PI / 2)
	else:
		return basis

## Unapplies a global rotation matrix (that is applied to all incoming vertices)
## in favor of a local rotation around the origin of the transform. Typically,
## [code]global_rotation[/code] will be [member BamParser.rotation_matrix].
static func rotate_transform_locally(global_rotation: Transform3D, local_rotation: Transform3D) -> Transform3D:
	var transform = global_rotation.inverse()
	transform *= local_rotation.rotated_local(Vector3(-1, 0, 0), -PI / 2)
	return transform

static func merge_main_and_alpha_images(texture: Image, alpha: Image, alpha_file_channel:=0) -> ImageTexture:
	texture.convert(Image.FORMAT_RGBA8)
	var texture_size := texture.get_size()
	if texture_size != alpha.get_size():
		alpha.resize(
			texture_size.x, texture_size.y,
			Image.INTERPOLATE_CUBIC
		)
		
	var color: Color
	for y in range(texture.get_height()):
		for x in range(texture.get_width()):
			color = texture.get_pixel(x, y)
			color.a = alpha.get_pixel(x, y)[alpha_file_channel]
			texture.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(texture)
