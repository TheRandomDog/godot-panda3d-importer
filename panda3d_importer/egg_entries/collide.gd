extends EggEntry
class_name EggCollide

enum CollideType { PLANE, POLYGON, POLYSET, SPHERE, BOX, INV_SPHERE, TUBE }
enum CollideFlag { EVENT, INTANGIBLE, DESCEND, KEEP, LEVEL }

const string_to_type = {
	'Plane': CollideType.PLANE,
	'Polygon': CollideType.POLYGON,
	'Polyset': CollideType.POLYSET,
	'Sphere': CollideType.SPHERE,
	'Box': CollideType.BOX,
	'InvSphere': CollideType.INV_SPHERE,
	'Tube': CollideType.TUBE
}
const string_to_flag = {
	'event': CollideFlag.EVENT,
	'intangible': CollideFlag.INTANGIBLE,
	'descend': CollideFlag.DESCEND,
	'keep': CollideFlag.KEEP,
	'level': CollideFlag.LEVEL,
}

var collide_type: CollideType
var collide_flags: Array[CollideFlag]

var uses_one_polygon: bool:
	get:
		return collide_type == CollideType.PLANE or collide_type == CollideType.POLYGON
		
var uses_area: bool:
	get:
		return CollideFlag.EVENT in collide_flags or CollideFlag.INTANGIBLE in collide_flags

var uses_static_body: bool:
	get:
		return CollideFlag.INTANGIBLE not in collide_flags

var keep_visual_mesh: bool:
	get:
		return CollideFlag.KEEP in collide_flags

func read_entry() -> void:
	var args: PackedStringArray = contents().split(' ')
	collide_type = string_to_type[args[0]]
	for flag_string in args.slice(1):
		collide_flags.append(string_to_flag[flag_string])
