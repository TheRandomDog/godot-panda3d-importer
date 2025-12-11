@tool
extends StandardMaterial3D
class_name PandaMaterial3D

static var materials_created: Array[PandaMaterial3D]
static var mutex := Mutex.new()

static func create() -> PandaMaterial3D:
	var material := PandaMaterial3D.new()
	# By default, Panda3D does not apply lighting to objects unless
	# explicitly told to do so. To preserve the look of a Panda3D model,
	# we'll change the shading mode on all materials to unshaded.
	material.shading_mode = material.SHADING_MODE_UNSHADED
	# By default, Panda3D vertex colors are stored in sRGB color space.
	material.vertex_color_is_srgb = true
	return material

func commit() -> PandaMaterial3D:
	mutex.lock()
	for material in materials_created:
		if is_eq(material):
			return material
	materials_created.append(self)
	mutex.unlock()
	return self

"""func finalize(next_pass: StandardMaterial3D = null) -> StandardMaterial3D:
	var surface_id := get_surface_id()
	if surface_id in surfaces:
		return surfaces[surface_id]

	var material := StandardMaterial3D.new()
	material.next_pass = next_pass
	# Textures
	if features & Feature.TEXTURE:
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		#texture.get_image().decompress()  # This is necessary to detect alpha
		#if texture.get_image().detect_alpha() > 0:
		#	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if features & Feature.ALPHA:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		#material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Colors
	material.vertex_color_use_as_albedo = features & Feature.VERTEX_COLORS
	if features & Feature.ALBEDO_COLOR:
		material.albedo_color = color

	# Billboard
	if features & Feature.BILLBOARD:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.billboard_keep_scale = true

	# By default, Panda3D does not apply lighting to objects unless
	# explicitly told to do so. To preserve the look of a Panda3D model,
	# we'll change the shading mode on all materials to unshaded.
	material.shading_mode = material.SHADING_MODE_UNSHADED

	# By default, Panda3D vertex colors are stored in sRGB color space.
	material.vertex_color_is_srgb = true

	#prints('FEA', features, 'TEX', material.albedo_texture, 'COL', material.albedo_color)
	surfaces[surface_id] = material
	return material"""

func is_texture_eq(other: PandaMaterial3D) -> bool:
	return (albedo_texture == other.albedo_texture) or (
		albedo_texture is PandaImageAndAlphaTexture
		and other.albedo_texture is PandaImageAndAlphaTexture
		and albedo_texture.image == other.albedo_texture.image
		and albedo_texture.alpha_image == other.albedo_texture.alpha_image
		and albedo_texture.alpha_channel == other.albedo_texture.alpha_channel
		and albedo_texture.use_alpha == other.albedo_texture.use_alpha
	)

func is_eq(other: PandaMaterial3D) -> bool:
	return (
		is_texture_eq(other)
		and albedo_color == other.albedo_color
		and transparency == other.transparency
		and blend_mode == other.blend_mode
		and vertex_color_use_as_albedo == other.vertex_color_use_as_albedo
		and billboard_mode == other.billboard_mode
	)
