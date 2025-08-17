extends PandaNode
class_name PandaSequenceNode

const ExclusiveChildNode3D = preload("../extras/exclusive_child_node_3d.gd")

var anim_interface: PandaAnimInterface

## Called when [member BamObject.object_data] should be processed.
## Will send a [b]warning[/b] to the console if not overridden in some way.
func parse_object_data():
	super()
	anim_interface = PandaAnimInterface.new()
	anim_interface.parse_data(bam_parser)

func convert() -> Node3D:
	var node := super()
	var animation := Animation.new()
	for child: Node3D in node.find_children('*', 'Node3D', false, false):
		var track_index := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(track_index, node.get_path_to(child))
		animation.track_insert_key(track_index, anim_interface.get_frame_time(track_index), {'method': 'show', 'args': []})
	var animation_player := anim_interface.make_animation_player(animation)
	animation_player.name = 'SequencePlayer'
	node.add_child(animation_player)
	node.move_child(animation_player, 0)
	return node

func _get_godot_node() -> Node3D:
	return ExclusiveChildNode3D.new()
