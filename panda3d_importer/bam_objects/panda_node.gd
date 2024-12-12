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
var tags: Dictionary[String, String]  # 4.4+
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

## Applies common changes to a given [param node] inheriting [Node3D].
func _convert_node3d_properties(node: Node3D) -> void:
	# Change our node name to the one in our BAM Object
	if name:
		node.name = name
	# Apply our transform
	o_transform.apply_to_node(node)

## Applies [PandaRenderEffect] objects to a given [param node] inheriting [Node3D].
func _convert_effects(node: Node3D) -> void:
	for effect in o_effects.o_effects:
		effect.apply_to_node(node)

## Converts this PandaNode into a Godot node. [br][br] Typically, this will be a
## [VisualInstance3D] or a node that inherits it. BAM Objects that inherit
## PandaNode can override this method to customize the conversion process.
func convert() -> VisualInstance3D:
	var node := VisualInstance3D.new()
	convert_node(node)
	return node

## Applies common changes to a [Camera3D] node.
func convert_camera(node: Camera3D) -> void:
	_convert_node3d_properties(node)

## Applies common changes to a given [param node] inheriting [VisualInstance3D],
## and recursively converts any child [PandaNode] objects and adds them as
## children of the [param parent]. [br][br]
##
## Usually [param parent] will not be set and the parent will be the [param node] itself.
func convert_node(node: VisualInstance3D, parent: Node3D = null) -> void:
	# Let's start converting this PandaNode to Godot.
	#
	# Of note is we expect a VisualInstance3D because a PandaNode is the base
	# class for objects that go on Panda3D's scene graph. The scene graph is
	# akin to Godot's scene tree, but importantly Panda3D's only contains objects
	# that have some sort of "render-ability" or are visual in nature. Thus,
	# it is most analogous to Godot's VisualInstance3D.
	#
	# There is one exception, which is Panda3D's CameraNode, which is considered
	# "render-able" / visual and inherits PandaNode. Godot's Camera3D does not
	# inherit VisualInstance3D but rather Node3D. To handle this, we have a
	# separate method that sets Node3D-related properties and only add-on 
	# VisualInstance3D-related properties in this method.
	
	if not parent:
		parent = node
	
	_convert_node3d_properties(node)
	# TODO: Process PandaRenderState, perhaps by tossing the node to it?
	_convert_effects(node)
	
	var relevant := false
	# TODO: Sorting
	if relevant and ProjectSettings.get_setting('rendering/anti_aliasing/quality/use_taa', false):
		push_warning('%s contains opaque sorted objects. In this Godot version, while Temporal
			Anti-Aliasing (TAA) is enabled, these objects cannot be reliably sorted.')
	
	gather_children(node, parent)

## Converts this [PandaNode] into an [Animation] resoucre. [br][br] Will return
## [code]null[/code] if this PandaNode has no [PandaAnimBundleNode] children.
func convert_animation() -> Animation:
	for child_info in o_children:
		if child_info.node is PandaAnimBundleNode:
			return child_info.node.convert_animation()
	return null

## Loops through each child of this [PandaNode] and converts it to a Godot node,
## before adding it as a child of the given [param parent].
func gather_children(node: VisualInstance3D, parent: Node3D):
	for child_info in o_children:
		var child_node := child_info.node.convert()
		parent.add_child(child_node)
