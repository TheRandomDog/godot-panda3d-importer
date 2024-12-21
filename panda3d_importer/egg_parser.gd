extends RefCounted
class_name EggParser
## A class that can load and parse an Egg file.

enum CoordinateSystem { Y_UP, Z_UP, Y_UP_LEFT, Z_UP_LEFT }

const ELEMENT_END = 'ELEMENT_END'
const EGG_END = 'EGG_END'

var entry_type_handlers: Dictionary

var source_file_name: String
var error := OK
var converting_to_resource := false

var regex := RegEx.new()
var comment_remover := RegEx.new()
var whitespace_trimmer := RegEx.new()
var matches: Array[RegExMatch]
var index: int = 0
var entry_stack: Array[EggEntry]

var coordinate_system := CoordinateSystem.Y_UP
var rotation_matrix: Transform3D

var vertex_pools: Dictionary[String, EggVertexPool] = {}
var textures: Dictionary[String, EggTexture]
var root_groups: Array[EggGroup]
var root_tables: Array[EggTable]
var egg_contents: Array[Dictionary]
var entry_stacks: Array[Dictionary]

var characters: Array[EggCharacterGroup]

var surfaces: Array[Surface]


func _init():
	regex.compile('<(.+?)>\\s*"?(.*?)"?{\\s*"?([^}<"]*)"?|}')
	comment_remover.compile('\\/\\/.+|\\/\\*.+\\*\\/')
	whitespace_trimmer.compile('\\s+')

## Returns the parent [EggEntry] of the current entry being parsed.
## [b]NOTE:[/b] This function only returns a meaningful value during
## [method EggParser.parse].
func _parent_entry() -> EggEntry:
	if entry_stack.size() > 1:
		return entry_stack[-2]
	return null

## Returns the parent [EggEntry] of a given [param entry].
## [b]NOTE:[/b] This function only returns a meaningful value during
## [method EggParser.parse].
func _parent_of_entry(entry: EggEntry) -> EggEntry:
	var entry_index = entry_stack.find(entry)
	assert(entry_index != -1)
	if entry_index != 0:
		return entry_stack[entry_index - 1]
	return null

## Reads data from an Egg file and calls [method EggParser.parse].
func load(path: String) -> Error:
	source_file_name = path
	return parse(FileAccess.get_file_as_bytes(path), path.ends_with('.pz'))

## Reads and parses the content of the Egg file data.
func parse(byte_array: PackedByteArray, compressed := false) -> Error:
	if compressed:
		byte_array = byte_array.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	var file_contents := byte_array.get_string_from_utf8()
	if not file_contents:
		return FAILED
	
	file_contents = comment_remover.sub(file_contents, '', true)
	matches = regex.search_all(file_contents)
	var entry = next_entry()

	while entry['type'] != EGG_END:
		#prints(entry['type'], entry)
		var type = entry['type']
		if type == null:
			# We didn't get anything here. It may have been a line with a comment on it.
			# Let's try again.
			entry = next_entry()
			continue
		elif type == ELEMENT_END:
			var finished_element = entry_stacks.pop_back()
			if entry_stacks:
				entry_stacks[-1]['children'].append(finished_element)
			else:
				egg_contents.append(finished_element)
			entry = next_entry()
			continue
		
		#var name: String = entry['name']
		#var contents = entry['contents']
		
		var entry_dict = {
			'type': entry['type'],
			'name': entry['name'],
			'contents': entry['contents'],
			'children': []
		}
		entry_stacks.append(entry_dict)
		entry = next_entry()
	
	resolve()
	
	return OK

func resolve():
	# Now that we've parsed the contents of this Egg file, we'll go over the
	# top-level entries to record information relevant to the whole Egg file
	# and start the root of nested entries like groups.
	for entry in egg_contents:
		var name = entry['name']
		match entry['type']:
			'CoordinateSystem':
				# TODO: This is non-compliant with Egg Syntax, as this entry
				# should be able to be placed anywhere in the file.
				set_coordinate_system(entry)
			'Texture':
				textures[name] = EggTexture.new(self, entry)
			'VertexPool':
				vertex_pools[name] = EggVertexPool.new(self, entry)
			'Group':
				root_groups.append(EggGroup.make_group(self, entry))
			'Table':
				root_tables.append(EggTable.new(self, entry))

## Sets the coordiante system of this egg file based on the passed egg [param entry].
func set_coordinate_system(entry: Dictionary):
	var value = entry['contents'].to_lower()
	var basis := Basis.IDENTITY
	match value:
		'z-up', 'z-up-right':
			coordinate_system = CoordinateSystem.Z_UP
			basis = basis.rotated(Vector3(-1, 0, 0), -PI / 2)
		'z-up-left':
			coordinate_system = CoordinateSystem.Z_UP_LEFT
			basis = basis.rotated(Vector3(-1, 0, 0), -PI / 2).scaled(Vector3(1, 1, -1))
		'y-up-left':
			coordinate_system = CoordinateSystem.Y_UP_LEFT
			basis = basis.scaled(Vector3(1, 1, -1))
		'y-up', 'y-up-right':
			pass  # This is Godot's coordinate system :)
		var other:
			push_warning('Unhandled coordinate system value: "%s"' % other)
	rotation_matrix = Transform3D(basis, Vector3())
			
	for pool in vertex_pools.values():
		for vertex in pool.verticies.values():
			vertex.coordinate_system = coordinate_system
	
func make_model() -> VisualInstance3D:
	var node = VisualInstance3D.new()
	node.name = source_file_name.get_file()
	
	converting_to_resource = true
	for group in root_groups:
		print('EGG PARSER here, looking at group %s...' % group.entry_name)
		var child_node = group.convert()
		if child_node:
			node.add_child(child_node)
	converting_to_resource = false
	
	return node
	
func make_animation() -> Animation:
	var animation
	converting_to_resource = true
	for table in root_tables:
		print('EGG PARSER here, looking at table %s...' % table.name())
		var bundle = table.bundles[0]
		animation = bundle.convert_animation()
	converting_to_resource = false
	return animation

## Converts the first root [EggGroup] into a [FontFile] resoucre.
##
## If [param small_caps] is [code]true[/code], lowercase alphabet glyphs
## are automatically generated from uppercase alphabet glyphs but scaled down by
## [param small_caps_scale], which may be useful if a font does not contain 
## lowercase letters.
func make_font(small_caps := false, small_caps_scale := 0.8) -> FontFile:
	converting_to_resource = true
	if not root_groups:
		parse_error("egg file contained no groups")
		return FontFile.new()
	var font := root_groups[0].convert_font(small_caps, small_caps_scale)
	converting_to_resource = false
	return font
	
func next_entry() -> Dictionary:
	var entry_response = {
		"type": null,
		"name": "",
		"contents": "",
	}
	if self.index >= self.matches.size():
		entry_response['type'] = EGG_END
		return entry_response
		
	var entry = self.matches[self.index]
	self.index += 1
	
	var type_string = entry.get_string(1)
	if not type_string:
		if entry.get_string() == '}':
			entry_response['type'] = ELEMENT_END
		elif entry.get_string().begins_with('/'):
			return entry_response
		else:
			assert(false)
	else:
		entry_response['type'] = type_string
		var name = entry.get_string(2)
		if name:
			entry_response['name'] = name.strip_edges()
		var contents = entry.get_string(3)
		if contents:
			entry_response['contents'] = contents.strip_edges().trim_suffix('/*').trim_suffix('//').trim_prefix('"').trim_suffix('"')
	return entry_response

func ensure(result: bool, message: String, error_value:=FAILED) -> void:
	if not result:
		parse_error(message, error_value)
	
func parse_error(message: String, error_value:=FAILED) -> void:
	error = error_value
	push_error(_get_assertion_prefix() + message)

func parse_warning(message: String) -> void:
	push_warning(_get_assertion_prefix() + message)

func _get_assertion_prefix() -> String:
	if converting_to_resource:
		return 'In "%s", while converting to a Godot resource, ' % source_file_name
	else:
		return 'In "%s", ' % source_file_name
