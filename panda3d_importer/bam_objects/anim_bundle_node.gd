extends PandaNode
class_name PandaAnimBundleNode
## A PandaNode that holds a pointer to our root [PandaAnimBundle].
##
## This node will act as our entry point for reading an animation.

var o_bundle: PandaAnimBundle

func parse_object_data() -> void:
	super()
	o_bundle = bam_parser.decode_and_follow_pointer() as PandaAnimBundle

## Converts our AnimBundleNode into a Godot animation.
func convert_animation() -> Animation:
	var animation := Animation.new()
	animation.loop_mode = configuration['loop_mode']
	animation.length = o_bundle.frame_count / o_bundle.fps
	animation.step = 1 / o_bundle.fps
	
	for group in o_bundle.o_children:
		# TODO: morph
		if group.name == '<skeleton>':
			_check_group_for_channels('%s/Skeleton3D:' % name, animation, group)
	
	return animation

## Checks each [PandaAnimGroup] recursively to read the data of the animation
## channels inside.
##
## An object inheriting [PandaAnimChannelBase] represents animation data for
## itself: typically, a joint/bone. These objects also inherit PandaAnimGroup,
## meaning they can be nested and have children, so we'll check recursively.
func _check_group_for_channels(path: String, animation: Animation, group: PandaAnimGroup, parent_tracks=null) -> void:
	for channel in group.o_children:
		bam_parser.ensure(
			channel is PandaAnimChannelBase,
			'In a nested AnimGroup child of an AnimBundleNode, instead of ' +
				'PandaAnimChannelBase, group was: %s' % channel
		)
		var data = channel.get_animation_data()
		
		# Let's keep a record of our animation track IDs for each type of transform
		# for this channel. We'll also keep a record of the max number of frames
		# we have data for that transform type, so we can extrapolate out if
		# necessary.
		# TODO: Probably best not to even extrapolate out if we already have
		# inserted the one keyframe we need.
		var our_tracks = {
			'position': -1, 'position_max': -1,
			'rotation': -1, 'rotation_max': -1,
			'scale': -1, 'scale_max': -1,
		}
		# Time to insert keyframes into the animation.
		# Let's loop through our transform types.
		for data_type in our_tracks.keys():
			if '_max' in data_type or not data[data_type]:
				# There is no data for this transform type, or,
				# it is not a transform type at all (just a record of max frames).
				continue
			
			var track_index: int
			var insert_key: Callable
			if data_type == 'position':
				track_index = animation.add_track(Animation.TYPE_POSITION_3D)
				insert_key = animation.position_track_insert_key
			elif data_type == 'rotation':
				track_index = animation.add_track(Animation.TYPE_ROTATION_3D)
				insert_key = animation.rotation_track_insert_key
			elif data_type == 'scale':
				track_index = animation.add_track(Animation.TYPE_SCALE_3D)
				insert_key = animation.scale_track_insert_key
			
			var frame_count = data[data_type].size()
			our_tracks[data_type] = track_index
			our_tracks[data_type + '_max'] = frame_count
			animation.track_set_path(track_index, path + channel.name)
			var value
			for i in range(frame_count):
				# Pull the value for this animation keyframe for this transform type.
				value = data[data_type][i]
				insert_key.call(track_index, animation.step * i, value)
		
		# Recursively check any children for more AnimChannels.
		_check_group_for_channels(path, animation, channel, our_tracks)
