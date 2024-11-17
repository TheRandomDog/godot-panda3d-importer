extends BamObject
class_name PandaInternalName

var name: String

func _to_string() -> String:
	return name

func parse_object_data() -> void:
	name = bam_parser.decode_string()
