extends EggEntry
class_name EggAnimBase
## The base class for animation entries in an egg file.

var fps: int
var frame_count: int
## Holds multiple series of animation values.
var values: Dictionary

func read_child(child: Dictionary) -> void:
	match child['type']:
		'V':
			# This is a series of animation values. We'll pass it off to an
			# overridable function for subclasses.
			read_values(child['contents'])
			set_frame_count()

## Processes the series of values for this animation entry.
## This function should be overridden by subclasses.
func read_values(values_string: String) -> void:
	pass

## Sets the number of frames for this animation entry to the largest value set.
func set_frame_count() -> void:
	var frame_counts := values.values().map(func(v: PackedFloat64Array): return v.size())
	frame_count = frame_counts.max()

func read_scalar(scalar: String, data: String) -> void:
	match scalar:
		'fps':
			fps = data.to_int()

## Returns a Dictionary containing animation data suitable for Godot's Animation
## resource. The Dictionary will be formatted like:
##
## [codeblock]{
##     "position": PackedVector3Array(),
##     "rotation": Array(),  # An array of quaternions
##     "scale": PackedVector3Array(),
## }[/codeblock]
func get_animation_data() -> Dictionary:
	return {
		'position': PackedVector3Array(),
		'rotation': Array(),
		'scale': PackedVector3Array(),
	}
