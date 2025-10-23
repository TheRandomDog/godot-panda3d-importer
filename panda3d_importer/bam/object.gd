@tool
extends RefCounted
class_name BamObject
## Base class for an object within a BAM file.
##
## BAM files are made up of objects. Each object has a type, an ID, and data.
## [br][br]
##
## BAM Object IDs are numerical in ascending order, and are used as a way for
## objects to reference/point to other objects. They start at ID 1, with 0
## being a sentinel value to represent "null" (i.e. an optional pointer).
## [br][br]
##
## How an object's data is read is dependent on its
## [member BamObject.object_type]. Read about [BamObjectType]s for more details.

## The parser for the BAM file this object was read from.
var bam_parser: BamParser:
	get:
		return datagram.get_parser()
## The type of this BAM object.
var object_type: BamObjectType
## The ID of this BAM object.
var object_id: int
## The datagram reader for this BAM object.
var datagram: PandaBAMDatagramReader
## If [code]true[/code], this [BamObject] instance is merely to satisfy an
## internal code check and cannot be resolved or parsed.
var is_placeholder = false
## If [code]true[/code], [method BamObject.parse_object_data] has already been
## called and all of the object's properties should be set.
var resolved := false
## The configuration for this [BAMObject] to use while parsing.
var configuration: Dictionary:
	get:
		return bam_parser.get_configuration(get_script())
var global_configuration: Dictionary:
	get:
		return bam_parser.get_global_configuration()

func _init(
	type: BamObjectType,
	id: int,
	with_datagram: PandaBAMDatagramReader
) -> void:
	object_type = type
	object_id = id
	datagram = with_datagram

## Creates a placeholder BAM Object instantiated from the given [param object_class].
## [br][br]If relevant to the purpose of the placeholder, an [param object_id] can be passed.
static func new_placeholder(object_class: Script, object_id:=-1) -> BamObject:
	assert(
		extended_by_script(object_class),
		"new_placeholder() expected a Script extending BamObject, received %s instead" %
			object_class.resource_path
	)
	var placeholder: BamObject = object_class.new(
		null,
		object_id,
		PandaBAMDatagramReader.new(PackedByteArray(), 0, [null])
	)
	placeholder.is_placeholder = true
	return placeholder

## Returns [code]true[/code] if the given [param script] extends [BamObject].
static func extended_by_script(script: Script) -> bool:
	while script.get_base_script() != null:
		if script.get_base_script() == BamObject:
			return true
		script = script.get_base_script()
	return false

## Attempts to avoid lingering cyclical references by clearing the values to
## [member BamObject.bam_parser], [member BamObject.bam_object_type], and any
## properties that begin with [code][/code], an internal value representing
## properties that point to other [BamObject]s.
#func cleanup() -> void:
#	is_placeholder = true
#	bam_parser = null
#	object_type = null
#	for property in get_property_list():
#		if property['name'].begins_with(''):
#			set(property['name'], null)

func _to_string() -> String:
	if is_placeholder:
		return "<PLACEHOLDER>"
	elif not resolved:
		# We're going to make a list of our parents.
		var type_chain := object_type.get_type_chain()
		var type_names := type_chain.map(
			func(type: BamObjectType) -> String:
				return type.name
		)
		return "<BamObject type_index: %s (%s), object_id: %s, datagram.size(): %s>" % [
			object_type.index,
			' <- '.join(type_names),
			object_id,
			datagram.size(),
		]
	elif object_type.has_exact_handler:
		return "<%s %s>" % [object_type.name, object_id]
	elif object_type.has_handler:
		return "<%s (%s) %s>" % [object_type.name, object_type.handler.resource_path, object_id]
	else:
		return "<%s (NO HANDLER) %s>" % [object_type.name, object_id]

func is_resolved() -> bool:
	return resolved

static func all_resolved(objects: Array) -> bool:
	return objects.all(func(object): return object.is_resolved())

## Instantiates the object type handler script for this object's type
## and calls [code]parse_object_data()[/code]. Returns the instantiated handler
## script, or [code]null[/code] if the object type has no suitable handler.
func resolve() -> Variant:
	if not object_type.has_handler:
		return null

	var bam_parser := datagram.get_parser()
	var inheritor: BamObject = object_type.handler.new(object_type, object_id, datagram)
	#inheritor.configuration = bam_parser.configuration.get(
	#	object_type.handler, {}
	#)
	bam_parser.objects[object_id] = inheritor
	inheritor.parse_object_data()
	inheritor.resolved = true
	bam_parser.resolving_object = null
	return inheritor

## Called when [member BamObject.object_data] should be processed.
## Will send a [b]warning[/b] to the console if not overridden in some way.
func parse_object_data() -> void:
	push_warning("The default BamObject.parse_object_data() was called. If " +
		"you've added a custom type handler, ensure you override " +
		"parse_object_data(), even if it's an empty method.")

func get_object(weakref: WeakRef) -> BamObject:
	return weakref.get_ref() if weakref else null

func get_objects_from_array(weakref_array: Array[WeakRef]) -> Array:
	return weakref_array.map(
		func(weakref: WeakRef) -> BamObject: return weakref.get_ref()
	)
