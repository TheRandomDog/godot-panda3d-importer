@tool
extends RefCounted
class_name BamParser
## A class that can read and parse a BAM file.

enum VertexEndianness { BIG_ENDIAN, LITTLE_ENDIAN }
enum BamObjectCode { PUSH, POP, ADJUNCT, REMOVE, FILE_DATA }

var _labels: Array
var source_file_path: String
var configurations := BAMParserConfigs.get_default()

var datagrams: PandaDatagramIterator
var current_datagram: PandaBAMDatagramReader
var error := OK
var import_dependency_manager := PandaImportDependencyManager.new()

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

func get_object(object_id: int, allow_null := false) -> BamObject:
	if object_id == 0:
		ensure(allow_null, "Received object_id=0 when allow_null=false")
		return null
	elif object_id in objects:
		return objects[object_id]
	else:
		# This object is not resolved yet, let's resolve it now.
		var unresolved_object_ids := \
			unresolved_objects[current_object_stream_depth].keys()
		ensure(
			object_id in unresolved_object_ids,
			"Trying to follow pointer to an object (%s) we don't share a depth with: %s" %
			[object_id, unresolved_object_ids],
		)
		return resolve_object(
			unresolved_objects[current_object_stream_depth][object_id]
		)

func get_dependency(
	path: String,
	type: PandaImportDependencyManager.DependencyType
) -> Resource:
	if not import_dependency_manager.is_valid_path(path):
		parse_error(
			('Tried to get a dependency with relative path ' +
				'"%s" without source_file_path being set.' % path),
			ERR_UNCONFIGURED
		)
	return import_dependency_manager.get_dependency(path, type)

## Loads a BAM data stream from a file and calls [method BamParser.parse].
func load(path: String) -> Error:
	source_file_path = path
	var byte_array := FileAccess.get_file_as_bytes(path)
	if not byte_array:
		return FileAccess.get_open_error()
	return parse(byte_array, path.ends_with('.pz'))

## Reads the content of the BAM data stream, creating and parsing [BamObject]s.
func parse(byte_array: PackedByteArray, compressed := false) -> Error:
	if compressed:
		byte_array = byte_array.decompress_dynamic(
			-1,
			FileAccess.COMPRESSION_DEFLATE,
		)
	if not byte_array:
		return ERR_FILE_EOF
	elif byte_array.slice(0, 6) != get_global_configuration().magic_header:
		return ERR_FILE_UNRECOGNIZED

	if source_file_path:
		import_dependency_manager._source_file_path = source_file_path
	else:
		source_file_path = '[blob]'
	if not import_dependency_manager.relative_path:
		push_warning(
			"Both source_file_path and Import Dependency Manager's "
			+ "relative_path are unset. BamParser may not be able to correctly "
			+ "load any BAM dependencies with relative paths."
		)

	datagrams = PandaDatagramIterator.new(byte_array, 6, PandaBAMDatagramReader, [self])

	var header := datagrams.take_next_datagram()
	version = [header.decode_u16(), header.decode_u16()]
	if version >= [5, 0]:
		vertex_endianness = header.decode_u8() as VertexEndianness
	if version >= [6, 27]:
		use_f64_stdfloats = header.decode_bool()
	if version < [6, 21]:
		use_object_stream_codes = false
	header = null

	for datagram: PandaBAMDatagramReader in datagrams:
		if error:
			break

		current_datagram = datagram
		match datagram.decode_object_code():
			BamObjectCode.PUSH:
				current_object_stream_depth += 1
				parse_object()
			BamObjectCode.POP:
				resolve_objects_at_current_depth()
				current_object_stream_depth -= 1
				pass
			BamObjectCode.ADJUNCT:
				parse_object()
			BamObjectCode.REMOVE:
				pass  # TODO
			BamObjectCode.FILE_DATA:
				pass  # TODO
	return error

func parse_object_type() -> BamObjectType:
	var type_index := current_datagram.decode_u16()
	if type_index == 0:
		return null
	elif type_index not in types_seen:
		var type_name := current_datagram.decode_string()
		var parent_types: Array[BamObjectType] = []

		var parent_type_count := current_datagram.decode_u8()
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
	var object_id := current_datagram.decode_pointer()
	#var remaining_data := current_datagram.take_remaining()
	ensure(object_id not in object_ids_seen, "Saw object ID %s twice!" % object_id)
	object_ids_seen.append(object_id)

	var object := BamObject.new(type, object_id, current_datagram)
	add_unresolved_object(object)

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
		return object.resolve()   # May return null

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

func get_model_root() -> PandaModelRoot:
	if not objects.has(1) or objects[1] is not PandaModelRoot:
		return null
	return objects[1]

func ensure(result: bool, message: String, error_value := FAILED) -> void:
	if not result:
		parse_error(message, error_value)

func parse_error(message: String, error_value:=FAILED) -> void:
	error = error_value
	push_error(_get_assertion_prefix() + message)

func parse_warning(message: String) -> void:
	push_warning(_get_assertion_prefix() + message)

func _get_assertion_prefix() -> String:
	if resolving_object:
		return 'In "%s", while resolving %s: ' % [source_file_path, resolving_object]
	elif converting_to_resource:
		return 'In "%s", while converting to a Godot resource: ' % source_file_path
	else:
		return 'In "%s": ' % source_file_path

func get_configuration(object_type_script: Script) -> Dictionary:
	return configurations.get(object_type_script, {})

func get_global_configuration() -> Dictionary:
	return configurations.get(BAMParserConfigs.GLOBAL, {})
