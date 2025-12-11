extends BamObject
class_name PandaNode
## The base object of anything renderable in Panda3D.
##
## Typically, objects that are data-oriented are children of other objects that
## inherit PandaNode to be visible in Panda3D's scene graph.

enum BoundsType { DEFAULT, BEST, SPHERE, BOX, FASTEST }
const OVERALL_BIT = 31

var name: String
var draw_control_mask: int = 0  # 6.2+
var draw_show_mask: int = 0xFFFFFFFF  #
var into_collide_mask: int = 0  # 4.12+
var bounds_type: BoundsType = BoundsType.DEFAULT  # 6.19+
var tags: Dictionary  # 4.4+

var _state: WeakRef
var state: PandaRenderState:
	get:
		return get_object(_state)

var _transform: WeakRef
var transform: PandaTransformState:
	get:
		return get_object(_transform)

var _effects: WeakRef
var effects: PandaRenderEffects:
	get:
		return get_object(_effects)

var _parents: Array[WeakRef]
func get_parents() -> Array[PandaNode]:
	var array: Array[PandaNode]
	array.assign(get_objects_from_array(_parents))
	return array

var children: Array[Child]
var stashed: Array[Child]

func parse_object_data() -> void:
	name = datagram.decode_string()

	_state = datagram.next_object_ref(PandaRenderState)
	_transform = datagram.next_object_ref(PandaTransformState)
	_effects = datagram.next_object_ref(PandaRenderEffects)

	if bam_parser.version < [6, 2]:
		var draw_mask := datagram.decode_u32()
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
		draw_control_mask = datagram.decode_u32()
		draw_show_mask = datagram.decode_u32()

	if bam_parser.version >= [4, 12]:
		into_collide_mask = datagram.decode_u32()
	if bam_parser.version >= [6, 19]:
		bounds_type = datagram.decode_u8() as BoundsType
	if bam_parser.version >= [4, 4]:
		var tags_length := datagram.decode_u32()
		var key: String
		var value: String
		for i in range(tags_length):
			key = datagram.decode_string()
			value = datagram.decode_string()
			tags[key] = value

	_parents = datagram.next_object_ref_array(PandaNode)
	children.assign(BAMStruct.make_array(Child, datagram))
	stashed.assign(BAMStruct.make_array(Child, datagram))

## Applies [PandaRenderEffect] objects to a given [param node] inheriting [Node3D].
func _convert_effects(node: Node3D) -> void:
	for effect in effects.get_effects():
		effect.apply_to_node(node, self)

## Converts this PandaNode into a Godot node. [br][br] Typically, this will be
## a [Node3D] or a node that inherits it. BAM Objects that inherit
## PandaNode can override this method to customize the conversion process.
func convert() -> Node:
	var node := _get_godot_node()
	_convert_node(node)
	return node

func _get_godot_node() -> Node3D:
	for effect in effects.get_effects():
		if effect is PandaCharacterJointEffect:
			return BoneAttachment3D.new()
	return Node3D.new()

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
	transform.apply_to_node(node, self)

	# TODO: Process PandaRenderState, perhaps by tossing the node to it?
	_convert_effects(node)
	# TODO: Sorting

	gather_children(node, parent)


## Loops through each child of this [PandaNode] and converts it to a Godot node,
## before adding it as a child of the given [param parent].
func gather_children(node: Node3D, parent: Node3D):
	for child_info in children:
		var child_node := child_info.node.convert()
		if child_node:
			var existing_child := parent.get_node_or_null(NodePath(child_node.name))
			if existing_child:
				for grandchild in child_node.get_children(true):
					grandchild.owner = null
					grandchild.reparent(existing_child)
					grandchild.owner = existing_child
				child_node.free()
			else:
				parent.add_child(child_node)
				child_node.owner = parent


class Child extends BAMStruct:
	var _node: WeakRef
	var node: PandaNode:
		get:
			return get_object(_node)

	var sort: int

	func _init(datagram: PandaBAMDatagramReader) -> void:
		_node = datagram.next_object_ref(PandaNode)
		sort = datagram.decode_s32()
