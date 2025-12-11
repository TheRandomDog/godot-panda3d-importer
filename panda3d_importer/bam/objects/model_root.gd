extends PandaModelNode
class_name PandaModelRoot

#func convert() -> Node3D:
#	var result := super()
#
#	var animations := make_animations()
#
#	var model_bundles := get_bundles()
#	for bundle_name in model_bundles.animations:
#		#var part_bundles := model_bundles.get_parts_named(bundle_name)
#		#if not part_bundles:
#
#		var parts_node := result.find_child(bundle_name)
#		var animation_player: AnimationPlayer
#		if not parts_node:
#			parts_node = Node.new()
#			parts_node.name = bundle_name
#			result.add_child(parts_node)
#			parts_node.owner = result
#
#			animation_player = AnimationPlayer.new()
#			parts_node.add_child(animation_player)
#			animation_player.owner = parts_node
#		else:
#			animation_player = parts_node.get_node(^'AnimationPlayer')
#
#		if not animation_player.has_animation_library(&''):
#			animation_player.add_animation_library(&'', AnimationLibrary.new())
#		var animation_library := animation_player.get_animation_library(&'')
#
#		var bundles := model_bundles.get_animations_named(bundle_name)
#		animation_library.add_animation(bundle_name, bundles[0].convert_animation())
#		for bundle_index in range(1, bundles.size()):
#			animation_library.add_animation(
#				'%s.%d' % [bundle_name, bundle_index],
#				bundles[bundle_index].convert_animation(),
#			)
#
#	return result

## Converts the contents of the BAM file to a [Node3D].
func make_scene_tree(animation_libraries: Array[AnimationLibrary] = []) -> Node3D:
	bam_parser.converting_to_resource = true
	var result := self.convert()

	animation_libraries.append(make_animation_library())
	#var animation_libraries := external_animations + [make_animation_library()]
	bam_parser.converting_to_resource = true

	for animation_library in animation_libraries:
		var animation_list := animation_library.get_animation_list()
		var override_animation_name := animation_library.resource_name

		var current_bundle_name: String
		var current_bundle_start_index: int
		var current_animation_library: AnimationLibrary

		for library_index in animation_list.size():
			var animation_name := animation_list[library_index]
			var animation := animation_library.get_animation(animation_name)
			if not current_bundle_name or not animation_name.begins_with(current_bundle_name):
				current_bundle_name = animation_name
				current_bundle_start_index = library_index

				var animation_player: AnimationPlayer

				var parts_node := result.find_child(current_bundle_name)
				if not parts_node:
					parts_node = Node.new()
					parts_node.name = animation_name
					result.add_child(parts_node)
					parts_node.owner = result

					animation_player = AnimationPlayer.new()
					parts_node.add_child(animation_player)
					animation_player.owner = parts_node
				else:
					animation_player = parts_node.get_node(^'AnimationPlayer')

				if animation_player.has_animation_library(&''):
					current_animation_library = animation_player.get_animation_library(&'')
				else:
					current_animation_library = AnimationLibrary.new()
					animation_player.add_animation_library(&'', current_animation_library)

			if override_animation_name:
				animation_name = override_animation_name
				var animation_index := library_index - current_bundle_start_index
				if animation_index > 0:
					animation_name += '.%d' % animation_index
			current_animation_library.add_animation(animation_name, animation)

	bam_parser.converting_to_resource = false
	return result


## Converts the contents of a BAM file to a [Node2D]. Only flat geometry
## will be converted into [MeshInstance2D] children; anything else will be
## converted into empty [Node2D] children. You can also control what is
## considered "flat" by adjusting the [param flat_max_depth] value, which
## defaults to [code]0.1[/code].[br][br]
##
## [b][method BamParser.parse] must be called before calling this method.[/b]
func make_scene_tree_from_flat_meshes(flat_max_depth := 0.1) -> Node2D:
	var replace_node = func(old: Node, new: Node) -> void:
		old.replace_by(new)
		old.free()

	var get_mesh_rect = func(aabb: AABB, x: Vector3.Axis, y: Vector3.Axis) -> Rect2:
		return Rect2(aabb.position[x], aabb.position[y], aabb.size[x], aabb.size[y])

	bam_parser.converting_to_resource = true
	var model := self.convert()

	var node_2d := Node2D.new()
	node_2d.name = name
	node_2d.scale = global_configuration.make_2d_scale
	replace_node.call(model)

	for child_3d: Node in node_2d.find_children('*', '', true, false):
		var replace_2d: Node2D
		if child_3d is ExclusiveChildNode3D:
			replace_2d = ExclusiveChildNode2D.new()
		elif (child_3d is not MeshInstance3D or
				child_3d.get_aabb().get_shortest_axis_size() >= flat_max_depth):
			replace_2d = Node2D.new()
		else:
			# Going from meters -> pixels will severly decrease the size
			# of the outputted node, so we'll need an actual conversion.
			var mesh_scale: Vector3 = Vector3.ONE * (1.0 / global_configuration.pixel_size)
			var mesh_instance := child_3d as MeshInstance3D
			match mesh_instance.get_aabb().get_shortest_axis_index():
				Vector3.AXIS_X, Vector3.AXIS_Y:
					mesh_scale.z *= -1
				Vector3.AXIS_Z:
					mesh_scale.y *= -1

			for i in range(mesh_instance.mesh.get_surface_count()):
				var mesh_arrays := mesh_instance.mesh.surface_get_arrays(i)
				var material := mesh_instance.mesh.surface_get_material(i)

				var transform: Transform3D
				var curr_node: Node = child_3d
				while curr_node != model:
					transform *= curr_node.transform
					curr_node = curr_node.get_parent()
				var position := Vector2(transform.origin.x, -transform.origin.y) * mesh_scale.x

				var scaled_mesh := ArrayMesh.new()
				for surface in mesh_instance.mesh.get_surface_count():
					var arrays := mesh_instance.mesh.surface_get_arrays(surface)
					var vertices = arrays[Mesh.ARRAY_VERTEX]
					for v in vertices.size():
						vertices[v] *= mesh_scale
					arrays[Mesh.ARRAY_VERTEX] = vertices
					scaled_mesh.add_surface_from_arrays(
						mesh_instance.mesh.surface_get_primitive_type(surface),
						arrays,
					)

				var aabb := scaled_mesh.get_aabb()
				var aabb_center := aabb.get_center()
				var mesh_rect: Rect2
				match aabb.get_shortest_axis_index():
					Vector3.AXIS_X:
						mesh_rect = get_mesh_rect.call(aabb, Vector3.AXIS_Y, Vector3.AXIS_Z)
					Vector3.AXIS_Y:
						mesh_rect = get_mesh_rect.call(aabb, Vector3.AXIS_X, Vector3.AXIS_Z)
					Vector3.AXIS_Z:
						mesh_rect = get_mesh_rect.call(aabb, Vector3.AXIS_X, Vector3.AXIS_Y)

				replace_2d = MeshInstance2D.new()
				replace_2d.mesh = scaled_mesh
				replace_2d.texture = material.albedo_texture
				replace_2d.position = position
				replace_2d.set_meta('rect', mesh_rect)

		replace_2d.name = child_3d.name
		replace_node.call(child_3d, replace_2d)

	bam_parser.converting_to_resource = false
	return node_2d


func make_animation_library() -> AnimationLibrary:
	bam_parser.converting_to_resource = true
	var library := AnimationLibrary.new()

	var model_bundles := get_bundles()
	for bundle_name in model_bundles.animations:
		var bundles := model_bundles.get_animations_named(bundle_name)

		library.add_animation(bundle_name, bundles[0].convert_animation())
		for bundle_index in range(1, bundles.size()):
			library.add_animation(
				'%s.%d' % [bundle_name, bundle_index],
				bundles[bundle_index].convert_animation(),
			)
		#libraries.append(library)
		#libraries[bundle_name] = library

	bam_parser.converting_to_resource = false
	return library

#func make_animation_libraries() -> Array[AnimationLibrary]:
#	bam_parser.converting_to_resource = true
#	var libraries: Array[AnimationLibrary]
#
#	var model_bundles := get_bundles()
#	for bundle_name in model_bundles.animations:
#		var bundles := model_bundles.get_animations_named(bundle_name)
#		var library := AnimationLibrary.new()
#
#		library.add_animation(bundle_name, bundles[0].convert_animation())
#		for bundle_index in range(1, bundles.size()):
#			library.add_animation(
#				'%s.%d' % [bundle_name, bundle_index],
#				bundles[bundle_index].convert_animation(),
#			)
#		libraries.append(library)
#		#libraries[bundle_name] = library
#
#	bam_parser.converting_to_resource = false
#	return libraries


## Converts this [PandaNode] into a [FontFile] resoucre.
##
## If [param small_caps] is [code]true[/code], lowercase alphabet glyphs
## are automatically generated from uppercase alphabet glyphs but scaled down by
## [param small_caps_scale], which may be useful if a font does not contain
## lowercase letters.
func make_font(small_caps := false, small_caps_scale := 0.8) -> FontFile:
	bam_parser.converting_to_resource = true
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
	bam_parser.converting_to_resource = false
	return font

#region Parts & Animations
func get_bundles() -> Bundles:
	var bundles := Bundles.new()
	for part_bundle in bam_parser.get_objects_of_type(PandaPartBundleNode):
		bundles.add_part(part_bundle)
	for anim_bundle in bam_parser.get_objects_of_type(PandaAnimBundleNode):
		bundles.add_animation(anim_bundle)
	return bundles


class Bundles:
	var parts: Dictionary[String, Dictionary]
	var animations: Dictionary[String, Array]

	func add_part(part_bundle_node: PandaPartBundleNode) -> void:
		for bundle in part_bundle_node.get_bundles():
			if bundle.name not in parts:
				parts[bundle.name] = {}
			parts[bundle.name][bundle] = part_bundle_node

	func add_animation(anim_bundle_node: PandaAnimBundleNode) -> void:
		var bundle := anim_bundle_node.bundle
		if bundle.name not in animations:
			animations[bundle.name] = []
		animations[bundle.name].append(anim_bundle_node)

	func get_parts_named(name: String) -> Dictionary[PandaPartBundle, PandaPartBundleNode]:
		var result: Dictionary[PandaPartBundle, PandaPartBundleNode]
		result.assign(parts.get(name, {}))
		return result

	func get_animations_named(name: String) -> Array[PandaAnimBundleNode]:
		var result: Array[PandaAnimBundleNode]
		result.assign(animations.get(name, []))
		return result
#endregion
