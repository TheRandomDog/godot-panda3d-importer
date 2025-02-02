@tool
extends RefCounted
class_name BamParser
## A class that can read and parse a BAM file.

enum VertexEndianness { BIG_ENDIAN, LITTLE_ENDIAN }
enum BamObjectCode { PUSH, POP, ADJUNCT, REMOVE, FILE_DATA }
enum DependencyType { TEXTURE }

var magic_header := PackedByteArray([0x70, 0x62, 0x6A, 0x00, 0x0A, 0x0D])
const MAX_U16 = 0xFFFF
const MAX_U32 = 0xFFFFFFFF
static var rotation_matrix := Transform3D(
	Basis().rotated(Vector3(-1, 0, 0), -PI / 2),
	Vector3()
)

var _labels: Array
var source_file_name: String
var configuration := ParserConfigs.get_bam_parser_configuration()

var read_contents: PackedByteArray
var read_byte_offset := 0
var datagram_size_remaining := 0
var error := OK
var dependency_function: Callable

var version: Array[int]
var vertex_endianness: VertexEndianness = VertexEndianness.LITTLE_ENDIAN
var use_f64_stdfloats = false
var use_object_stream_codes = true
var current_object_stream_depth := -1

var types_seen: Dictionary
func resolve_type(type_index: int) -> BamObjectType:
	return types_seen[type_index]

var object_ids_seen: Array[int]
# Each index on the array represents stream depth.
var unresolved_objects: Array[Dictionary] 
var objects: Dictionary
var resolving_object: BamObject
var converting_to_resource := false

func add_unresolved_object(object: BamObject) -> void:
	if current_object_stream_depth >= unresolved_objects.size():
		unresolved_objects.resize(current_object_stream_depth + 1)
	unresolved_objects[current_object_stream_depth][object.object_id] = object
	
func remove_unresolved_object(object_id: int) -> void:
	unresolved_objects[current_object_stream_depth].erase(object_id)

## Swaps the read contents/state of the [BamParser] with [param new_contents].
## The old state is returned in an Array containing: [[member BamParser.read_contents],
## [member BamParser.read_byte_offset], [member BamParser.datagram_size_remaining]].
## [br][br]
## 
## This function is useful to start reading other buffered content in a safe way.
## It is used by [BamObject]s to read their object data as an example.
## [br][br]
##
## [b]IMPORTANT:[/b] When you are finished parsing, you must call
## [method BamParser.unswap_read_contents] with the array that this method returns.
func swap_read_contents(new_contents: PackedByteArray) -> Array:
	var old_info: Array = [read_contents, read_byte_offset, datagram_size_remaining]
	read_contents = new_contents
	read_byte_offset = 0
	datagram_size_remaining = new_contents.size()
	return old_info

## Restores the old read contents/state of the [BamParser] from [param old_info].
func unswap_read_contents(old_info: Array) -> void:
	read_contents = old_info[0]
	read_byte_offset = old_info[1]
	datagram_size_remaining = old_info[2]

## Sets and returns the size of the next datagram.
func _set_next_datagram_size() -> int:
	# The next datagram size is an unsigned int32 value.
	var size := read_contents.decode_u32(read_byte_offset)
	read_byte_offset += 4
	# Unless that size is 0xFFFFFFFF, which means the next
	# datagram size is actually the next unsigned int64 value.
	if size == MAX_U32:
		size = read_contents.decode_u64(read_byte_offset)
		read_byte_offset += 8
	datagram_size_remaining = size
	return size

## Returns [code]true[/code] if there is enough buffer in the datagram to read
## [param length] bytes.
func attempt_dg_size_check(length: int) -> bool:
	if length <= datagram_size_remaining:
		datagram_size_remaining -= length
		return true
	parse_error(
		"Datagram size check failed: %s > %s" % [length, datagram_size_remaining],
		ERR_FILE_EOF
	)
	return false

## Decodes and returns a boolean from the datagram buffer.
func decode_bool() -> bool:
	var value := decode_u8()
	return bool(value)

## Decodes and returns an unsigned int8 from the datagram buffer.
func decode_u8() -> int:
	if attempt_dg_size_check(1):
		var read := read_contents.decode_u8(read_byte_offset)
		read_byte_offset += 1
		return read
	return 0

## Decodes and returns an unsigned int16 from the datagram buffer.
func decode_u16() -> int:
	if attempt_dg_size_check(2):
		var read := read_contents.decode_u16(read_byte_offset)
		read_byte_offset += 2
		return read
	return 0
	
## Decodes and returns an unsigned int64 from the datagram buffer.
##
## [br][br][b]NOTE:[/b] This does not include a datagram size check. Do not use.
func _decode_u64_for_next_size() -> int:
	var read := read_contents.decode_u32(read_byte_offset)
	read_byte_offset += 4
	return read
		
## Decodes and returns an unsigned int32 from the datagram buffer.
func decode_u32() -> int:
	if attempt_dg_size_check(4):
		var read := read_contents.decode_u32(read_byte_offset)
		read_byte_offset += 4
		return read
	return 0
		
## Decodes and returns a signed int32 from the datagram buffer.
func decode_s32() -> int:
	if attempt_dg_size_check(4):
		var read := read_contents.decode_s32(read_byte_offset)
		read_byte_offset += 4
		return read
	return 0
		
## Decodes and returns a float from the datagram buffer.
func decode_float() -> float:
	if attempt_dg_size_check(4):
		var read := read_contents.decode_float(read_byte_offset)
		read_byte_offset += 4
		return read
	return 0.0
		
## Decodes and returns a double from the datagram buffer.
func decode_double() -> float:
	if attempt_dg_size_check(8):
		var read := read_contents.decode_double(read_byte_offset)
		read_byte_offset += 8
		return read
	return 0.0

## Decodes and returns a float (or double if [member BamParser.use_f64_stdfloats]
## is [code]true[/code]) from the datagram buffer.
func decode_stdfloat() -> float:
	if use_f64_stdfloats:
		return decode_double()
	else:
		return decode_float()

## Calls [param decode_function] twice to read two successive values from the
## datagram buffer, and returns the values in a [Vector2].
func decode_vector2(decode_function: Callable) -> Vector2:
	return Vector2(
		decode_function.call(),
		decode_function.call(),
	)

## Calls [param decode_function] three times to read three successive values
## from the datagram buffer, and returns the values in a [Vector3].
func decode_vector3(decode_function: Callable) -> Vector3:
	return Vector3(
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
	)

## Calls [param decode_function] four times to read four successive values
## from the datagram buffer, and returns the values in a [Vector4].
func decode_vector4(decode_function: Callable) -> Vector4:
	return Vector4(
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
		decode_function.call(),
	)

## Decodes 16 successive [code]stdfloat[/code] values from the datagram buffer,
## and returns the values as a [Projection] (matrix).
func decode_projection() -> Projection:
	return Projection(
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
		decode_vector4(decode_stdfloat),
	)

## Decodes four successive [code]stdfloat[/code] values from the datagram buffer,
## and returns the values as a [Color].
func decode_color() -> Color:
	return Color(
		decode_stdfloat(),
		decode_stdfloat(),
		decode_stdfloat(),
		decode_stdfloat(),
	)

## Decodes and returns a [String] from the datagram buffer.
func decode_string() -> String:
	var length := decode_u16()
	if attempt_dg_size_check(length):
		var slice := read_contents.slice(read_byte_offset, read_byte_offset + length)
		read_byte_offset += length
		return slice.get_string_from_utf8()
	return String()

## Decodes and returns a pointer to another [BamObject] from the datagram buffer.
func decode_pointer() -> int:
	# TODO: u32 must be handled when we hit 0xFFFF
	return decode_u16()

## Decodes a pointer to another [BamObject] from the datagram buffer and attempts
## to resolve said BamObject before returning it.
func decode_and_follow_pointer(allow_null:=false) -> BamObject:
	var object_id := decode_pointer()
	if object_id == 0:
		ensure(allow_null, "Received object_id=0 when allow_null=false")
		return null
	elif object_id in objects:
		return objects[object_id]
	else:
		# This object is not resolved yet, let's resolve it now.
		var unresolved_object_ids := unresolved_objects[current_object_stream_depth].keys()
		ensure(
			object_id in unresolved_object_ids,
			"Trying to follow pointer to an object (%s) we don't share a depth with: %s" %
				[object_id, unresolved_object_ids]
		)
		return resolve_object(unresolved_objects[current_object_stream_depth][object_id])

## Slices and returns [param size] bytes from the datagram buffer.
func take_size(size: int) -> PackedByteArray:
	if attempt_dg_size_check(size):
		var slice := read_contents.slice(read_byte_offset, read_byte_offset + size)
		read_byte_offset += size
		return slice
	return PackedByteArray()

## Slices and returns the remaining bytes from the datagram buffer.
func take_remaining() -> PackedByteArray:
	var slice := read_contents.slice(read_byte_offset, read_byte_offset + datagram_size_remaining)
	read_byte_offset += datagram_size_remaining
	datagram_size_remaining = 0
	return slice

func get_dependency_path(path: String) -> String:
	if path.begins_with('.'):
		if (not source_file_name) or source_file_name == '[blob]':
			parse_error(
				('Tried to get a dependency with relative path ' +
					'"%s" without source_file_name being set.' % path),
				ERR_UNCONFIGURED
			)
			return ''
		return source_file_name.trim_prefix('res://').get_base_dir().path_join(path).simplify_path()
	return path

func get_dependency(path: String, type: DependencyType) -> Resource:
	path = get_dependency_path(path)
	if not path:
		return
	elif dependency_function:
		return dependency_function.call(path, type)
	return ResourceLoader.load('res://' + path)

## Loads a BAM data stream from a file and calls [method BamParser.parse].
func load(path: String) -> Error:
	source_file_name = path
	return parse(FileAccess.get_file_as_bytes(path), path.ends_with('.pz'))

## Reads the content of the BAM data stream, creating and parsing [BamObject]s.
func parse(byte_array: PackedByteArray, compressed := false) -> Error:
	read_contents = byte_array
	if compressed:
		read_contents = read_contents.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if not read_contents:
		return FileAccess.get_open_error()

	if not source_file_name:
		source_file_name = '[blob]'

	if read_contents.slice(0, 6) != magic_header:
		return ERR_FILE_UNRECOGNIZED
	read_byte_offset += 6
	
	_set_next_datagram_size()
	version = [decode_u16(), decode_u16()]
	
	if version >= [5, 0]:
		vertex_endianness = decode_u8() as VertexEndianness
	if version >= [6, 27]:
		use_f64_stdfloats = decode_bool()
	if version < [6, 21]:
		use_object_stream_codes = false
		
	#print('BAM Version: ', version)
	#print('Vertex Endianness: ', vertex_endianness)
	#print('Use 64-bit floats: ', use_f64_stdfloats)
	#print('Supports BAM Object Codes: ', use_object_stream_codes)
	#print('\n\n')

	while read_byte_offset < read_contents.size():
		if error:
			break
		var _datagram_size := _set_next_datagram_size()
		#print('Next Datagram Size: ', datagram_size, '  | Byte Offset: ', read_byte_offset)
		match next_object_code():
			BamObjectCode.PUSH:
				#print('Next Object Code: PUSH\n-- vvv --  | Byte Offset: ', read_byte_offset)
				current_object_stream_depth += 1
				parse_object()
			BamObjectCode.POP:
				#print('Next Object Code: POP\n-- vvv --  | Byte Offset: ', read_byte_offset)
				resolve_objects_at_current_depth()
				current_object_stream_depth -= 1
				pass
			BamObjectCode.ADJUNCT:
				#print('Next Object Code: ADJUNCT\n-- vvv --  | Byte Offset: ', read_byte_offset)
				parse_object()
			BamObjectCode.REMOVE:
				pass  # TODO
			BamObjectCode.FILE_DATA:
				pass  # TODO
		#print('---------\n')
	return error

func next_object_code() -> int:
	if not use_object_stream_codes:
		return BamObjectCode.ADJUNCT
	return decode_u8()
	
func parse_object_type() -> BamObjectType:
	var type_index := decode_u16()  # TODO: u16 unless we're out of them
	if type_index == 0:
		return null
	elif type_index not in types_seen:
		var type_name := decode_string()
		var parent_types: Array[BamObjectType] = []
		
		var parent_type_count := decode_u8()
		for i in range(parent_type_count):
			var parent_type = self.parse_object_type()
			if parent_type:
				parent_types.append(parent_type)
		
		var new_type_entry := BamObjectType.new(type_index, type_name, parent_types)
		types_seen[type_index] = new_type_entry
		return new_type_entry
	else:
		return resolve_type(type_index)

func parse_object() -> void:
	var type := parse_object_type()
	var object_id := parse_object_id()
	var remaining_data := take_remaining()
	ensure(object_id not in object_ids_seen, "Saw object ID %s twice!" % object_id)
	object_ids_seen.append(object_id)
	
	var object := BamObject.new(self, type, object_id, remaining_data)
	add_unresolved_object(object)
	
func parse_object_id() -> int:
	return decode_pointer()

func resolve_object(object: BamObject) -> Variant:
	if object.object_id in objects:
		return objects[object.object_id]
	else:
		# We only remove the unresolved/base BamObject from the unresolved list,
		# as opposed to also adding the final resolved BamObject. That's because
		# only the BamObject itself knows what subclass it will resolve to.
		# Because of this, it will add itself to our objects array.
		remove_unresolved_object(object.object_id)
		resolving_object = object
		return object.resolve()   # May be null

func resolve_objects_at_current_depth() -> void:
	# Now that we have everything we need, we'll resolve our current objects.
	# We'll start with the first one, and, if it has dependencies, it will make
	# a call to decode_and_follow_pointer() which also resolves for us.
	var objects_to_resolve := unresolved_objects[current_object_stream_depth].values()
	# Objects, once resolved, will be removed from the array by resolve_object().
	# What remains will be cyclical references that will get passed through again.
	#objects_to_resolve.reverse()
	while objects_to_resolve:
		for object in objects_to_resolve:
			if error:
				return
			resolve_object(object)
		objects_to_resolve = unresolved_objects[current_object_stream_depth].values()

## Converts the contents of the BAM file to a [VisualInstance3D] node.
## [b][method BamParser.parse] must be called first.[/b]
func make_model() -> VisualInstance3D:
	assert(
		objects[1].object_type.name == 'ModelRoot',
		'The first object in %s is not ModelRoot. Ensure that this is a model file.' % source_file_name
	)
	
	converting_to_resource = true
	var model_root := objects[1] as PandaModelRoot
	var result := model_root.convert()
	converting_to_resource = false
	return result

## Converts the contents of the BAM file to a [Node2D] that has a [Sprite2D]
## child for every "flat" geom in the BAM. Useful for converting texture cards
## to Godot's 2D space.[br][br]
##
## [b][method BamParser.parse] must be called first.[/b][br][br]
##
## [b]NOTE:[/b] These sprites can often be very big by default. The scale value
## of a sprite is already set to mirror the aspect ratio seen in the BAM geom.
## When adjusting a sprite's scale, you may either want to adjust the scale of
## the [b]parent Node2D[/b], or maintain the aspect ratio of the sprite's original scale.
func make_sprites() -> Node2D:
	assert(
		objects[1].object_type.name == 'ModelRoot',
		'The first object in %s is not ModelRoot. Ensure that this is a model file.' % source_file_name
	)
	
	converting_to_resource = true
	var model_root := objects[1] as PandaModelRoot
	var model := model_root.convert()
	
	var node_2d := Node2D.new()
	node_2d.name = model_root.name
	node_2d.scale = configuration['parser']['make_sprite_scale']
	
	var check_children = func(check_children: Callable, node: Node) -> Sprite2D:
		for child in node.get_children():
			var sprite := check_children.call(check_children, child)
			if sprite:
				node_2d.add_child(sprite)
				
		if node is not MeshInstance3D or node.get_aabb().get_shortest_axis_size() >= 0.1:
			return null
			
		var mesh_instance := node as MeshInstance3D
		var aabb := mesh_instance.get_aabb()
		var aabb_center := aabb.get_center()
		var mesh_rect: Vector2
		var mesh_center: Vector2
		match aabb.get_shortest_axis_index():
			0:
				mesh_rect = Vector2(aabb.size.y, aabb.size.z)
				mesh_center = Vector2(aabb_center.y, aabb_center.z)
			1:
				mesh_rect = Vector2(aabb.size.x, aabb.size.z)
				mesh_center = Vector2(aabb_center.x, aabb_center.z)
			2:
				mesh_rect = Vector2(aabb.size.x, aabb.size.y)
				mesh_center = Vector2(aabb_center.x, aabb_center.y)
		
		for i in range(mesh_instance.mesh.get_surface_count()):
			var mesh_arrays := mesh_instance.mesh.surface_get_arrays(i)
			var material := mesh_instance.mesh.surface_get_material(i)
			if material.albedo_texture:
				var uvs: Array = Array(mesh_arrays[Mesh.ARRAY_TEX_UV])
				if uvs.size() != 4:
					continue
					
				var sprite := Sprite2D.new()
				sprite.name = node.name
				sprite.texture = material.albedo_texture
				var size := sprite.texture.get_size()
				sprite.region_rect = Rect2(uvs.min() * size, Vector2(0, 0))
				sprite.region_rect.end = uvs.max() * size
				sprite.region_enabled = true
				var transform: Transform3D
				var curr_node: Node = node
				while curr_node != model:
					transform *= curr_node.transform
					curr_node = curr_node.get_parent()
					
				sprite.position = Vector2(transform.origin.x, -transform.origin.y) * size
				sprite.scale = (mesh_rect / sprite.region_rect.size) * size
				sprite.offset = (-mesh_center / sprite.scale) * size
				return sprite
		return null
	
	converting_to_resource = false
	check_children.call(check_children, model)
	return node_2d

## Converts the contents of the BAM file to a [Dictionary] that has an entry
## for every "flat" geom in the BAM. These entries are structured as follows:
## [codeblock]
## {'node_name': {
##     'texture': AtlasTexture,
##     'position': Vector2
##     'scale': Vector2
## }}
## [/codeblock][br][br]
##
## [b][method BamParser.parse] must be called first.[/b][br][br]
##
## [b]NOTE:[/b] The position and scale are the values found in the original BAM
## geom. For example, if you have a BAM file for a GUI that already has its
## elements pre-placed, you could use this method to attach several [TextureRect]s
## to a parent [Control] node and set the position and scale of each child to match
## accordingly. Just keep in mind that these textures are often very big by default
## -- scaling a parent [Control] node as needed is recommended. 
func make_atlas_textures() -> Dictionary:
	assert(
		objects[1].object_type.name == 'ModelRoot',
		'The first object in %s is not ModelRoot. Ensure that this is a model file.' % source_file_name
	)
	
	converting_to_resource = true
	var model_root := objects[1] as PandaModelRoot
	var model := model_root.convert()
	
	var check_children = func(check_children: Callable, node: Node) -> Dictionary:
		var textures := {}
		for child in node.get_children():
			textures.merge(check_children.call(check_children, child))
		
		if node is not MeshInstance3D or node.get_aabb().get_shortest_axis_size() >= 0.1:
			return textures
			
		var mesh_instance := node as MeshInstance3D
		var aabb := mesh_instance.get_aabb()
		var aabb_center := aabb.get_center()
		var mesh_rect: Vector2
		var mesh_center: Vector2
		match aabb.get_shortest_axis_index():
			0:
				mesh_rect = Vector2(aabb.size.y, aabb.size.z)
				mesh_center = Vector2(aabb_center.y, aabb_center.z)
			1:
				mesh_rect = Vector2(aabb.size.x, aabb.size.z)
				mesh_center = Vector2(aabb_center.x, aabb_center.z)
			2:
				mesh_rect = Vector2(aabb.size.x, aabb.size.y)
				mesh_center = Vector2(aabb_center.x, aabb_center.y)

		for i in range(mesh_instance.mesh.get_surface_count()):
			var mesh_arrays := mesh_instance.mesh.surface_get_arrays(i)
			var material := mesh_instance.mesh.surface_get_material(i)
			if material.albedo_texture:
				var uvs: Array = Array(mesh_arrays[Mesh.ARRAY_TEX_UV])
				if uvs.size() != 4:
					continue
					
				var texture := AtlasTexture.new()
				texture.atlas = material.albedo_texture
				var size := texture.atlas.get_size()
				texture.region = Rect2(uvs.min() * size, Vector2(0, 0))
				texture.region.end = uvs.max() * size
				var transform: Transform3D
				var curr_node: Node = node
				while curr_node != model:
					transform *= curr_node.transform
					curr_node = curr_node.get_parent()
				var scale := (mesh_rect / texture.region.size) * size
				
				textures[mesh_instance.name] = {
					'texture': texture,
					'position': (
						Vector2(transform.origin.x, -transform.origin.y) * size  # Position on mesh
						- ((texture.get_size() * scale) / 2)  # Center origin (instead of top-left)
						- (mesh_center * size)  # Offset "center" according to mesh center offset
					),
					'scale': scale,
				}
		return textures
	
	converting_to_resource = false
	return check_children.call(check_children, model)

## Converts the contents of the BAM file to an [Animation] resource.
## [b][method BamParser.parse] must be called first.[/b]
func make_animation() -> Animation:
	assert(
		objects[1].object_type.name == 'ModelRoot',
		'The first object in %s is not ModelRoot. Ensure that this is an animation file.' % source_file_name
	)
	
	converting_to_resource = true
	var model_root := objects[1] as PandaModelRoot
	var result := model_root.convert_animation()
	converting_to_resource = false
	return result
	
func make_font(small_caps := false, small_caps_scale := 0.8) -> FontFile:
	assert(
		objects[1].object_type.name == 'ModelRoot',
		'The first object in %s is not ModelRoot. Ensure that this is a font file.' % source_file_name
	)
	
	converting_to_resource = true
	var model_root := objects[1] as PandaModelRoot
	var result := model_root.convert_font(small_caps, small_caps_scale)
	converting_to_resource = false
	return result

## Attempts to avoid lingering cyclical references by clearing the values to
## [member BamParser.types_seen], and calling [code]cleanup()[/code] to and
## clearing the values of [member BamParser.unresolved_objects] and
## [member BamParser.objects].
func cleanup() -> void:
	for type in types_seen.values():
		type.parent_types.clear()
	types_seen.clear()
	for depth_level in unresolved_objects:
		for object in depth_level.values():
			object.cleanup()
	unresolved_objects.clear()
	for object in objects.values():
		object.cleanup()
	objects.clear()

func ensure(result: bool, message: String, error_value:=FAILED) -> void:
	if not result:
		parse_error(message, error_value)
	
func parse_error(message: String, error_value:=FAILED) -> void:
	error = error_value
	push_error(_get_assertion_prefix() + message)

func parse_warning(message: String) -> void:
	push_warning(_get_assertion_prefix() + message)

func _get_assertion_prefix() -> String:
	if resolving_object:
		return 'In "%s", while resolving %s, ' % [source_file_name, resolving_object]
	elif converting_to_resource:
		return 'In "%s", while converting to a Godot resource, ' % source_file_name
	else:
		return 'In "%s", ' % source_file_name
