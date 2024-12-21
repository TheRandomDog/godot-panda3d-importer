extends EggEntry
class_name EggGroup
## An entry that provides structure for other entries in an egg file.
##
## Groups can hold many things, but some subclasses of [EggGroup] are used if a
## group contains certain elements. If a group has polygon data, [EggGeomGroup]
## is used. [EggCharacterGroup] is used if a group has character data.

const SwitchManager = preload("../switch_manager.gd")

## [code]true[/code] if there is a [code]<Switch>[/code] child entry in this group.
## In Panda3D, this is an indicator that child groups should be treated similar
## to animation frames, only showing one at a time and switching them every so often.
var switch_enabled := false
## [code]true[/code] if there is a [code]<Billboard>[/code] child entry in this group.
## Billboards are visual objects that always face the camera. This entry's value
## corresponds to the geometry's [member BaseMaterial3D.billboard_mode] value.
var billboard := false

## If [member EggGroup.switch_enabled] is [code]true[/code], this value determines
## how often to cycle through child groups.
var fps: float = 0
var bin: String
var draw_order: int
var visible: bool

var parent: EggGroup
var subgroups: Array[EggGroup]
var lights: Array[EggPointLight]

func read_entry() -> void:
	parent = entry_dict.get('parent_group')

## Returns an [EggGroup] instance or an instance of the subclass, depending on
## the type of children in the group.[br][br]
##
## Will return an [EggCharacterGroup] instance if the group has a
## [code]<Dart>[/code] child entry, or will return an [EggGeomGroup] instance if
## the group has a [code]<Polygon>[/code] child entry.
static func make_group(egg_parser: EggParser, entry: Dictionary) -> EggGroup:
	for child in entry['children']:
		if child['type'] == 'Dart':
			# TODO: the value could be off
			return EggCharacterGroup.new(egg_parser, entry)
		elif child['type'] == 'Polygon':
			return EggGeomGroup.new(egg_parser, entry)
	return EggGroup.new(egg_parser, entry)

## Converts this Group into a Godot [VisualInstance3D] node. [br][br]
##
## The contents of the group determine specifically what node gets generated.
## For example, if the group contains polygon data, this method will instead
## return a [MeshInstance3D].
func convert() -> Node3D:
	var node = VisualInstance3D.new()
	convert_node(node)
	return node

func convert_node(node: Node3D, parent: Node3D = null) -> void:
	if not parent:
		parent = node
	
	for light in lights:
		var light_instance := light.make_light(egg_parser)
		node.add_child(light_instance)
		
	if switch_enabled:
		var switch_manager := SwitchManager.new()
		switch_manager.name = 'SwitchManager'
		switch_manager.fps = fps
		node.add_child(switch_manager, false, Node.INTERNAL_MODE_BACK)
		
	gather_subgroups(parent)
	if entry_name:
		node.name = entry_name

## Converts this [EggGroup] into a [FontFile] resoucre.
##
## If [param small_caps] is [code]true[/code], lowercase alphabet glyphs
## are automatically generated from uppercase alphabet glyphs but scaled down by
## [param small_caps_scale], which may be useful if a font does not contain 
## lowercase letters.
func convert_font(small_caps := false, small_caps_scale := 0.8) -> FontFile:
	var font := FontFile.new()
	if egg_parser.source_file_name:
		font.font_name = egg_parser.source_file_name.get_basename().trim_prefix('res://')
	var font_size := 10
	var font_size_v := Vector2(font_size, 0)
	font.fixed_size = font_size
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	
	var named_subgroups: Dictionary[String, EggGroup]
	for subgroup in subgroups:
		named_subgroups[subgroup.name()] = subgroup
	
	# Find our design size hint group.
	if 'ds' not in named_subgroups:
		egg_parser.parse_error('No design size hint found. Ensure that this is a font file.')
		return FontFile.new()
	var design_size_group: EggGroup = named_subgroups['ds']
	
	# The "ds" group contains a single vertex containing metadata about the font.
	# X is margin and (after global transform) Y is line height.
	var ds_point: Vector3 = design_size_group.lights[0].vertex_ref.verticies[0].position
	var margin: float = ds_point[0] * font_size
	var line_height: float = ds_point[1] * font_size
	var space_advance: float = line_height * 0.25
	
	var font_textures: Array[Texture2D]
	var glyph_heights: Dictionary[int, float]
	var tallest_glyph_height: float
	var deepest_glyph_height: float
	
	# Each subgroup should have a polygon child entry for the glyph, and
	# a PointLight child entry that has metadata about kerning.
	for subgroup_name in named_subgroups.keys():
		if subgroup_name == 'ds' or not subgroup_name.is_valid_int():
			continue
		var subgroup: EggGroup = named_subgroups[subgroup_name]
		
		var char: int = subgroup_name.to_int()
		var glyph_is_uppercase_letter = char >= 65 and char <= 90
		var glyph_is_lowercase_letter = char >= 97 and char <= 122
		if small_caps and glyph_is_lowercase_letter:
			continue
		
		var glyph_meta_point: Vector3 = subgroup.lights[0].vertex_ref.verticies[0].position
		var advance: float = glyph_meta_point[0]
		
		if subgroup is EggGeomGroup:
			var glyph_polygon: EggPolygon = subgroup.polygons[0]
			var glyph_texture := glyph_polygon.get_texture().texture
			assert(glyph_texture != null)
			var glyph_texture_image := glyph_texture.get_image()
			var glyph_texture_format := glyph_texture_image.get_format()
			#print(glyph_texture_image.get_data().slice(1100, 1300))
			if glyph_texture_format == Image.FORMAT_L8:
				# We must convert our black/white texture into one with alpha.
				# The easiest way to do this is just to double the data,
				# as luminosity is directly proportional to opacity here.
				var new_image_data: PackedByteArray
				var old_image_data := glyph_texture_image.get_data()
				new_image_data.resize(old_image_data.size() * 2)
				for i in range(old_image_data.size()):
					var byte := old_image_data[i]
					if byte != 0:
						new_image_data[i * 2] = byte
						new_image_data[(i * 2) + 1] = byte
						
				glyph_texture_image.set_data(
					glyph_texture_image.get_width(),
					glyph_texture_image.get_height(),
					glyph_texture_image.has_mipmaps(),
					Image.FORMAT_LA8,
					new_image_data
				)
				glyph_texture.set_image(glyph_texture_image)
			elif glyph_texture_format == Image.FORMAT_RGBA8:
				glyph_texture_image.convert(Image.FORMAT_LA8)
				glyph_texture.set_image(glyph_texture_image)
			else:
				assert(
					glyph_texture_image.get_format() == Image.FORMAT_LA8,
					"Expected glyph texture image format 1, got %s" % glyph_texture_image.get_format()
				)
			
			var texture_size := glyph_texture.get_size()
			var texture_index := -1
			if glyph_texture not in font_textures:
				font_textures.append(glyph_texture)
				texture_index = font_textures.size() - 1
				font.set_texture_image(0, font_size_v, texture_index, glyph_texture_image)
			else:
				texture_index = font_textures.find(glyph_texture)
			
			var uvs: PackedVector2Array
			var verts: PackedVector3Array
			for vertex in glyph_polygon.vertex_ref.verticies:
				uvs.append(vertex.uv_coords)
				verts.append(vertex.position)
				
			var uv_rect := Rect2(
				uvs[0].x, uvs[2].y,
				uvs[1].x - uvs[0].x, uvs[0].y - uvs[2].y
			)
			uv_rect *= Transform2D().scaled(glyph_texture.get_size())
			
			var under_baseline: float = verts[2].y
			var over_baseline: float = verts[0].y
			if over_baseline > tallest_glyph_height:
				tallest_glyph_height = over_baseline
			if -under_baseline > deepest_glyph_height:
				deepest_glyph_height = -under_baseline
			glyph_heights[char] = over_baseline
			
			var glyph_rect := Rect2(
				verts[0].x, verts[2].y, 
				verts[1].x - verts[0].x, verts[0].y - verts[2].y
			)
			glyph_rect.grow_individual(0, margin * font_size, 0, margin * font_size)
			
			font.set_glyph_texture_idx(0, font_size_v, char, texture_index)
			font.set_glyph_uv_rect(0, font_size_v, char, uv_rect)
			font.set_glyph_size(0, font_size_v, char, glyph_rect.size * font_size * 2)
			
			if small_caps and glyph_is_uppercase_letter:
				var lowercase_char := char + 32
				glyph_heights[lowercase_char] = over_baseline * small_caps_scale
				
				font.set_glyph_texture_idx(0, font_size_v, lowercase_char, texture_index)
				font.set_glyph_uv_rect(0, font_size_v, lowercase_char, uv_rect)
				font.set_glyph_size(0, font_size_v, lowercase_char, 
					font.get_glyph_size(0, font_size_v, char) * small_caps_scale
				)
				font.set_glyph_advance(0, font_size, lowercase_char, 
					Vector2(advance * font_size * 2 * small_caps_scale, 0)
				)
			
		font.set_glyph_advance(0, font_size, char, Vector2(advance * font_size * 2, 0))
		font.render_glyph(0, font_size_v, char)
	
	font.set_cache_ascent(0, font_size, tallest_glyph_height * font_size * 2)
	font.set_cache_descent(0, font_size, deepest_glyph_height * font_size * 2)
	for char in glyph_heights.keys():
		font.set_glyph_offset(0, font_size_v, char, 
			Vector2(0, -glyph_heights[char] * font_size * 2)
		)
	
	if not font.has_char(KEY_SPACE):
		font.set_glyph_advance(0, font_size, KEY_SPACE, Vector2(space_advance, 0))
	
	# We don't need the default size, and keeping it around prevents previews.
	font.remove_size_cache(0, Vector2(16, 0))
	return font

## Loops through each child [EggGroup] and calls [method EggGroup.convert] to
## create a Godot node, which is then added as a child of the given [param parent].
func gather_subgroups(parent: Node3D):
	for subgroup in subgroups:
		var child_node := subgroup.convert()
		parent.add_child(child_node)

func read_child(child: Dictionary) -> void:
	match child['type']:
		'Group':
			child['parent_group'] = self
			subgroups.append(EggGroup.make_group(egg_parser, child))
		'VertexPool':
			egg_parser.vertex_pools[child['name']] = EggVertexPool.new(egg_parser, child)
		'PointLight':
			lights.append(EggPointLight.new(egg_parser, child))
		'Switch':
			switch_enabled = EggEntry.as_bool(child)

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		'fps':
			fps = data.to_float()

func get_parent_character() -> EggCharacterGroup:
	var current_parent := parent
	while current_parent:
		if current_parent is EggCharacterGroup:
			return current_parent
		current_parent = current_parent.parent
	return null
