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
