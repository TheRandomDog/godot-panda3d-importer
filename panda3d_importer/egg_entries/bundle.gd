extends EggEntry
class_name EggBundle
## An egg entry that is the root for a tree of animation data.
##
## This class will act as our entry point for reading an animation.

var tables: Array[EggTable]

func read_child(child: Dictionary) -> void:
	if child['type'] != 'Table':
		return
	tables.append(EggTable.new(egg_parser, child))

## Converts our Bundle into a Godot animation.
func convert_animation() -> Animation:
	var animation := Animation.new()
	# TODO
	animation.loop_mode = Animation.LOOP_LINEAR
	for table in tables:
		# TODO: morph
		if '<skeleton>' in table.name():
			animation.length = table.tables[0].get_frame_count() / table.tables[0].get_fps()
			animation.step = 1.0 / table.tables[0].get_fps()
			_check_table_for_data('%s/Skeleton3D:' % name(), animation, table)
			
	return animation
	

## Checks each [EggTable] recursively to read the data of the animation entries
## inside.
##
## [EggTable] entries typically have child tables that will contain animation
## data for child joints (bones), so we'll check recursively.
func _check_table_for_data(path: String, animation: Animation, table: EggTable, parent_tracks=null):
	for table_part in table.tables:
		var data: Dictionary = table_part.get_animation_data()
		
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
			animation.track_set_path(track_index, path + table_part.name())
			var value
			for i in range(frame_count):
				# Pull the value for this animation keyframe for this transform type.
				value = data[data_type][i]
				insert_key.call(track_index, animation.step * i, value)
		
		# Recursively check any children for more animation data entries.
		_check_table_for_data(path, animation, table_part, our_tracks)
