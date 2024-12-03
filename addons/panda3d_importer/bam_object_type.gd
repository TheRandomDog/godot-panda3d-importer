extends RefCounted
class_name BamObjectType
## Contains information about a BAM Object type.
##
## BAM files are made up of objects. Each object has a type, an ID, and data.
## [br][br]
##
## Information about a BAM Object Type is given the first time a type appears.
## This includes an aribitrarily chosen type index, the name of the type, and
## information about the parent object types it inherits from. After the first
## time a new object type is established, only the index value is given.
## [br][br]
## 
## This add-on makes use of scripts to serve as handlers for each object type.
## When an object type is first established, we first see if we have a script
## that will handle the object type itself. If we don't, we check to see if we
## have any scripts that handle any of the parent types. That way, even if, say,
## there's a specific object that derives from [PandaNode] that we don't know
## about, we can still include and import the base properties of that object.
## [br][br]
##
## The format/order of the data for each object type is established in advanced,
## so that each object type script handler knows exactly how to parse its object
## data. When the format or order of the data needs to be changed or appended,
## Panda3D will typically bump the [b]BAM File Version Number[/b] which can be
## used as a switch-case in a script to change how to read the same type's data. 

## An array of object types that only add behavior or functionality in the
## Panda3D engine but are not relevant to this add-on.
const IGNORED_PARENT_TYPES = [
	# TypedWritable adds behavior to a class that lets classes write their state
	# to a datagram / BAM, but it does not write data itself.
	'TypedWritable',
	# Other behavior-only types that do not contain object data:
	'ReferenceCount',
	'CopyOnWriteObject',
]

## An arbitrarily-chosen value to identify this object type.
var index: int
## The name of this object type.
var name: String
## The direct parent(s) this object type derives from.
var parent_types: Array[BamObjectType]
## The [Script] resource that will handle objects instantiated with this type.
var handler: Resource

@warning_ignore("shadowed_variable")
func _init(index: int, name: String, parent_types: Array[BamObjectType]):
	self.index = index
	self.name = name
	for type in parent_types:
		if not IGNORED_PARENT_TYPES.any(func(i: String): return type.name.contains(i)):
			self.parent_types.append(type)
	self.handler = _get_handler_script()

## Returns the full hierarchy of type inheritance for this object type, starting
## with this object type itself.[br][br]
##
## [b]NOTE:[/b] The chain walks backwards fully for the first parent type, then
## the second parent type, and so on. The entries are not sorted by "depth".
func get_type_chain() -> Array[BamObjectType]:
	var type_chain: Array[BamObjectType] = [self]
	for parent_type in parent_types:
		type_chain.append_array(parent_type.get_type_chain())
	return type_chain

## Returns [code]true[/code] if [b]any[/b] script that can handle this object 
## type (this may include a parent object type script if there is no script for
## a specific derived object type).
func has_handler() -> bool:
	return handler.resource_path != ""

## Searches this object's type chain to find the first matching script handler.[br][br]
## Returns a [Resource] pointing to the script path if one is found, otherwise
## returns an empty [Resource].
func _get_handler_script() -> Resource:
	var relative_path_prefix: String = get_script().resource_path.get_base_dir()
	for type in get_type_chain():
		var script_path := "%s/bam_objects/%s.gd" % [
			relative_path_prefix, type.name.to_snake_case()
		]
		if ResourceLoader.exists(script_path):
			return load(script_path)
	return Resource.new()
