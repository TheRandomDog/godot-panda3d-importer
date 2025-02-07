extends BamObject
class_name PandaNode
## The base object of anything renderable in Panda3D.
##
## Typically, objects that are data-oriented are children of other objects that 
## inherit PandaNode to be visible in Panda3D's scene graph.

enum BoundsType { DEFAULT, BEST, SPHERE, BOX, FASTEST }
const OVERALL_BIT = 31

var name: String
var o_state: PandaRenderState
var o_transform: PandaTransformState
var o_effects: PandaRenderEffects
var draw_control_mask: int = 0  # 6.2+
var draw_show_mask: int = 0xFFFFFFFF  # 
var into_collide_mask: int = 0  # 4.12+
var bounds_type: BoundsType = BoundsType.DEFAULT  # 6.19+
var tags: Dictionary  # 4.4+
var o_parents: Array[PandaNode]
var o_children: Array[Child]
var o_stashed: Array[Child]

class Child:
	var node: PandaNode
	var sort: int

func parse_children() -> Child:
	var child := Child.new()
	child.node = bam_parser.decode_and_follow_pointer() as PandaNode
	child.sort = bam_parser.decode_s32()
	return child

func parse_object_data() -> void:
	name = bam_parser.decode_string()
	
	o_state = bam_parser.decode_and_follow_pointer() as PandaRenderState
	o_transform = bam_parser.decode_and_follow_pointer() as PandaTransformState
	o_effects = bam_parser.decode_and_follow_pointer() as PandaRenderEffects
	
	if bam_parser.version < [6, 2]:
		var draw_mask := bam_parser.decode_u32()
		if draw_mask == 0:
			# All off. Node is hidden.
			draw_control_mask = 1 << OVERALL_BIT
			draw_show_mask = ~(1 << OVERALL_BIT)
		elif draw_mask == 1 << 32:
			# Normally visible.
			draw_control_mask = 0
			draw_show_mask = 1 << 32
		else:
			# Some per-camera combination.
			draw_mask &= ~(1 << OVERALL_BIT)
			draw_control_mask = ~draw_mask
			draw_show_mask = draw_mask
	else:
		draw_control_mask = bam_parser.decode_u32()
		draw_show_mask = bam_parser.decode_u32()
		
	if bam_parser.version >= [4, 12]:
		into_collide_mask = bam_parser.decode_u32()
	if bam_parser.version >= [6, 19]:
		bounds_type = bam_parser.decode_u8() as BoundsType
	if bam_parser.version >= [4, 4]:
		var tags_length := bam_parser.decode_u32()
		var key: String
		var value: String
		for i in range(tags_length):
			key = bam_parser.decode_string()
			value = bam_parser.decode_string()
			tags[key] = value
		
	var parents_length := bam_parser.decode_u16()
	for i in range(parents_length):
		o_parents.append(bam_parser.decode_and_follow_pointer() as PandaNode)
		
	var children_length := bam_parser.decode_u16()
	for i in range(children_length):
		o_children.append(parse_children())
		
	var stashed_length := bam_parser.decode_u16()
	for i in range(stashed_length):
		o_stashed.append(parse_children())

## Applies [PandaRenderEffect] objects to a given [param node] inheriting [Node3D].
func _convert_effects(node: Node3D) -> void:
	for effect in o_effects.o_effects:
		effect.apply_to_node(node)

## Converts this PandaNode into a Godot node. [br][br] Typically, this will be
## a [Node3D] or a node that inherits it. BAM Objects that inherit
## PandaNode can override this method to customize the conversion process.
func convert() -> Node3D:
	var node := Node3D.new()
	_convert_node(node)
	return node

## Applies common changes to a given [param node] inheriting [Node3D],
## and recursively converts any child [PandaNode] objects and adds them as
## children of the [param parent]. [br][br]
##
## Usually [param parent] will not be set and the parent will be the
## [param node] itself.
func _convert_node(node: Node3D, parent: Node3D = null) -> void:
	# Let's start converting this PandaNode to Godot.
	if not parent:
		parent = node

	# Change our node name to the one in our BAM Object
	if name:
		node.name = name
	# Apply our transform
	o_transform.apply_to_node(node)

	# TODO: Process PandaRenderState, perhaps by tossing the node to it?
	_convert_effects(node)
	# TODO: Sorting
	
	gather_children(node, parent)

## Converts this [PandaNode] into an [Animation] resoucre. [br][br] Will return
## [code]null[/code] if this PandaNode has no [PandaAnimBundleNode] children.
func convert_animation() -> Animation:
	for child_info in o_children:
		if child_info.node is PandaAnimBundleNode:
			return child_info.node.convert_animation()
	return null
	
## Converts this [PandaNode] into a [FontFile] resoucre.
##
## If [param small_caps] is [code]true[/code], lowercase alphabet glyphs
## are automatically generated from uppercase alphabet glyphs but scaled down by
## [param small_caps_scale], which may be useful if a font does not contain 
## lowercase letters.
func convert_font(small_caps := false, small_caps_scale := 0.8) -> FontFile:
	var font := FontFile.new()
	if name:
		font.font_name = name.get_basename()
	var font_size := 10
	var font_size_v := Vector2(font_size, 0)
	font.fixed_size = font_size
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	
	# The simplest way to do this is just to convert the BAM into a Godot
	# model and pull from there. That way we don't have to rewrite a bunch of
	# code with only subtle differences.
	var model := self.convert()
	
	# Find our design size hint node.
	var design_size_node := model.find_child('ds', true, false)
	if design_size_node == null:
		bam_parser.parse_error('No design size hint found. Ensure that this is a font file.')
		return FontFile.new()
	
	# The "ds" mesh is actually a single vertex containing metadata about the font.
	# X is margin and (after global transform) Y is line height.
	var ds_mesh_arrays := (design_size_node as MeshInstance3D).mesh.surface_get_arrays(0)
	var ds_point: Vector3 = ds_mesh_arrays[Mesh.ARRAY_VERTEX][0]
	var margin: float = ds_point[0] * font_size
	var line_height: float = ds_point[1] * font_size
	var space_advance: float = line_height * 0.25
	
	var font_textures: Array[Texture2D]
	var glyph_nodes: Array[Node] = design_size_node.get_parent().find_children(
		'*', 'MeshInstance3D', false, false
	)
	var glyph_heights: Dictionary
	var tallest_glyph_height: float
	var deepest_glyph_height: float
	
	# Each mesh should have two surfaces: one is a polygon that is for the glyph,
	# and the other is a point that has metadata about kerning.
	for child in glyph_nodes:
		child = child as MeshInstance3D
		if child.name == 'ds' or not child.name.is_valid_int():
			continue
		
		var char := child.name.to_int()
		var glyph_is_uppercase_letter = char >= 65 and char <= 90
		var glyph_is_lowercase_letter = char >= 97 and char <= 122
		if small_caps and glyph_is_lowercase_letter:
			continue
		
		var glyph_meta_surface_arrays: Array = child.mesh.surface_get_arrays(0)
		var glyph_meta_point: Vector3 = glyph_meta_surface_arrays[Mesh.ARRAY_VERTEX][0]
		var advance: float = glyph_meta_point[0]
			
		if child.mesh.get_surface_count() > 1:
			var glyph_texture_surface_arrays: Array = child.mesh.surface_get_arrays(1)
			var glyph_texture_surface_material: BaseMaterial3D = child.mesh.surface_get_material(1)
			var glyph_texture := glyph_texture_surface_material.albedo_texture
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
			
			var uvs: PackedVector2Array = glyph_texture_surface_arrays[Mesh.ARRAY_TEX_UV]
			var uv_rect := Rect2(
				uvs[0].x, uvs[2].y,
				uvs[1].x - uvs[0].x, uvs[0].y - uvs[2].y
			)
			uv_rect *= Transform2D().scaled(glyph_texture.get_size())
			
			var verts: PackedVector3Array = glyph_texture_surface_arrays[Mesh.ARRAY_VERTEX]
			var under_baseline: float = verts[0].y
			var over_baseline: float = verts[2].y
			if over_baseline > tallest_glyph_height:
				tallest_glyph_height = over_baseline
			if -under_baseline > deepest_glyph_height:
				deepest_glyph_height = -under_baseline
			glyph_heights[char] = over_baseline
			
			var glyph_rect := Rect2(
				verts[0].x, verts[2].y, 
				verts[1].x - verts[0].x, verts[2].y - verts[0].y
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

## Loops through each child of this [PandaNode] and converts it to a Godot node,
## before adding it as a child of the given [param parent].
func gather_children(node: Node3D, parent: Node3D):
	for child_info in o_children:
		var child_node := child_info.node.convert()
		parent.add_child(child_node)
