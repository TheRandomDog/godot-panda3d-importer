@tool
extends RefCounted
class_name Surface

# We want to minimize the number of surfaces we're adding.
# That means the presence or absence of a feature, such as textures or
# vertex coloring, will each need an additional surface.
# Let's start with a default surface that has  

enum Feature {
	DEFAULT = 0,
	ALBEDO_COLOR = 1,
	VERTEX_COLORS = 2,
	TEXTURE = 4,
	ALPHA = 8,
	BILLBOARD = 16,
}

static var static_mutex := Mutex.new()

static var next_texture_id := 1
static var textures_to_id := {}
var features: int

static var surfaces: Dictionary[int, StandardMaterial3D]
static var colors: Dictionary[Color, int]

var color: Color
var texture: Texture2D
var texture_id := 0
var uv_coords: PackedVector2Array
var indices: PackedInt32Array

static func with_albedo_color(new_color: Color) -> Surface:
	var surface := Surface.new()
	surface.add_albedo_color(new_color)
	return surface
	
func add_albedo_color(new_color: Color) -> void:
	features |= Feature.ALBEDO_COLOR
	color = new_color

static func with_vertex_coloring() -> Surface:
	var surface := Surface.new()
	surface.features = Feature.VERTEX_COLORS
	return surface
	
static func from_surface_id(surface_id: int) -> Surface:
	var surface := Surface.new()
	surface.features = surface_id & 0xFF
	if surface.features & Feature.ALBEDO_COLOR:
		surface.color = colors.find_key((surface_id >> 8) & 0xFF)
	if surface.features & Feature.TEXTURE:
		surface.texture_id = (surface_id >> 16) & 0xFF
		surface.texture = textures_to_id.find_key(surface.texture_id)
	return surface 
	
func _to_string() -> String:
	var value := '<Surface id=%s' % get_surface_id()
	if features & Feature.ALBEDO_COLOR:
		value += ' albedo_color=%s' % color
	if features & Feature.VERTEX_COLORS:
		value += ' vertex_colors'
	if features & Feature.TEXTURE:
		value += ' texture=%s' % texture
	if features & Feature.ALPHA:
		value += ' alpha'
	if features & Feature.BILLBOARD:
		value += ' billboard'
	return value + '>'
	
func add_vertex_coloring() -> void:
	features |= Feature.VERTEX_COLORS

func add_texture(new_texture: Texture2D) -> void:
	features |= Feature.TEXTURE
	texture = new_texture
	Surface.static_mutex.lock()
	if texture in textures_to_id:
		texture_id = textures_to_id[texture]
	else:
		textures_to_id[texture] = next_texture_id
		texture_id = next_texture_id
		next_texture_id += 1
	Surface.static_mutex.unlock()
	
func add_alpha() -> void:
	features |= Feature.ALPHA
	
func add_billboard() -> void:
	features |= Feature.BILLBOARD
	
func get_surface_id() -> int:
	return (texture_id << 16) | (get_color_id() << 8) | features
		
func get_color_id() -> int:
	if color in colors:
		return colors[color]
	colors[color] = colors.size()
	return colors[color]
	
func finalize() -> StandardMaterial3D:
	var surface_id := get_surface_id()
	if surface_id in surfaces:
		return surfaces[surface_id]
	
	var material := StandardMaterial3D.new()
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
	return material
