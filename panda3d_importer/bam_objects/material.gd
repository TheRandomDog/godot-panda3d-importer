extends BamObject
class_name PandaMaterial

# TODO: Bam 6.39 introduced a new Material structure. This is the old structure from before 6.39
enum Flags { 
	AMBIENT = 1,
	DIFFUSE = 2,
	SPECULAR = 4,
	EMISSION = 8,
	LOCAL = 16,
	TWOSIDE = 32,
	ATTRIB_LOCK = 64,
	ROUGHNESS = 128,
	METALLIC = 256,
	BASE_COLOR = 512,
	REFRACTIVE_INDEX = 1024,
	USED_BY_AUTO_SHADER = 2048,
}

var name: String
var ambient: Color
var diffuse: Color
var specular: Color
var emission: Color
var shininess: float
var roughness: float
var flags: int

func parse_object_data() -> void:
	bam_parser.ensure(bam_parser.version < [6, 39], "Cannot read new material format yet")
	if bam_parser.version >= [5, 6]:
		name = bam_parser.decode_string()
	ambient = bam_parser.decode_color()
	diffuse = bam_parser.decode_color()
	specular = bam_parser.decode_color()
	emission = bam_parser.decode_color()
	var shininess_or_roughness = bam_parser.decode_stdfloat()
	flags = bam_parser.decode_u32()
	if flags & Flags.ROUGHNESS:
		roughness = shininess_or_roughness
	else:
		shininess = shininess_or_roughness
